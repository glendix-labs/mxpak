//// Runs the interactive mxpak Marketplace browser.
////

import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result
import mxpak/browser
import mxpak/config
import mxpak/downloader
import mxpak/error
import mxpak/marketplace/loader
import mxpak/marketplace/pagination
import mxpak/marketplace/process_manager
import mxpak/marketplace/state
import mxpak/marketplace/view
import mxpak/registry/content_api
import mxpak/registry/content_transport
import mxpak/registry/version_merger
import mxpak/registry/xas_parser
import mxpak/session
import shore
import shore/key
import shore/style
import shore/ui

/// Represents a Marketplace TUI startup failure.
pub type RunError {
  /// The Shore actor could not be started.
  TuiCouldNotStart(reason: actor.StartError)
}

/// Runs the Marketplace TUI until the user exits.
pub fn run(
  pat pat: String,
  project_root project_root: String,
) -> Result(Nil, RunError) {
  let exit = process.new_subject()
  use _shore <- result.try(
    shore.spec_with_subject(
      init: fn(subject) { init(pat, project_root, subject, exit) },
      view: view_fn,
      update: update,
      exit: exit,
      keybinds: shore.keybinds(
        exit: key.Ctrl("X"),
        submit: key.Enter,
        focus_clear: key.Esc,
        focus_next: key.Tab,
        focus_prev: key.BackTab,
      ),
      redraw: shore.on_update(),
    )
    |> shore.start
    |> result.map_error(TuiCouldNotStart),
  )
  process.receive_forever(exit)
  Ok(Nil)
}

// -- Tea: Init --
fn init(
  pat: String,
  project_root: String,
  shore_subject: process.Subject(state.Msg),
  exit_subject: process.Subject(Nil),
) -> #(state.Model, List(fn() -> state.Msg)) {
  let model =
    state.Model(
      pat: pat,
      project_root: project_root,
      all_widgets: [],
      filtered: option.None,
      page_index: 0,
      cursor: 0,
      selected: [],
      all_loaded: False,
      loader: option.None,
      offset: 0,
      search_query: "",
      view_mode: state.InitialLoading("위젯 목록 불러오는 중..."),
      status_msg: option.None,
      shore_subject: option.Some(shore_subject),
      exit_subject: option.Some(exit_subject),
    )
  let load_first = fn() {
    case content_transport.fetch_content_page(pat, 0, content_api.fetch_size) {
      Ok(page) ->
        state.LoaderUpdated(loader.LoaderUpdate(
          page.widgets,
          content_api.fetch_size,
          page.all_done,
        ))
      Error(_) -> state.LoaderUpdated(loader.LoaderUpdate([], 0, True))
    }
  }
  #(model, [load_first])
}

// -- Tea: View --
fn view_fn(model: state.Model) -> shore.Node(state.Msg) {
  case model.view_mode {
    state.InitialLoading(label) -> view.view_loading(label)
    state.Working(label) -> view.view_loading(label)
    state.Browse ->
      ui.col([
        view.view_browse(
          pagination.current_page_items(model),
          model.cursor,
          model.selected,
          model.page_index + 1,
          pagination.total_pages_str(model),
          model.status_msg,
          case model.all_loaded {
            True -> view.Loaded
            False -> view.Loading
          },
        ),
        ui.input("  검색: ", model.search_query, style.Fill, state.SearchChanged),
        ui.keybind(key.Up, state.MoveCursor(-1)),
        ui.keybind(key.Down, state.MoveCursor(1)),
        ui.keybind(key.Left, state.ChangePage(-1)),
        ui.keybind(key.Right, state.ChangePage(1)),
        ui.keybind(key.PageUp, state.ChangePage(-1)),
        ui.keybind(key.PageDown, state.ChangePage(1)),
        ui.keybind(key.Home, state.GoHome),
        ui.keybind(key.End, state.GoEnd),
        ui.keybind(key.Char(" "), state.ToggleSelection),
        ui.keybind(key.Enter, state.StartDownload),
      ])
    state.SelectVersion(name, versions, ver_cursor, _, _, _) ->
      ui.col([
        view.view_version(name, versions, ver_cursor, model.status_msg),
        ui.keybind(key.Up, state.MoveCursor(-1)),
        ui.keybind(key.Down, state.MoveCursor(1)),
        ui.keybind(key.Home, state.GoHome),
        ui.keybind(key.End, state.GoEnd),
        ui.keybind(key.Enter, state.ConfirmVersion),
        ui.keybind(key.Esc, state.GoBack),
      ])
  }
}

// -- Tea: Update --
fn update(
  model: state.Model,
  msg: state.Msg,
) -> #(state.Model, List(fn() -> state.Msg)) {
  case model.view_mode {
    state.Working(_) | state.InitialLoading(_) ->
      case msg {
        state.Quit
        | state.SessionReady(_)
        | state.VersionInfoReady(..)
        | state.ApiVersionsReady(..)
        | state.DownloadDone(..)
        | state.LoaderUpdated(_) -> update_inner(model, msg)
        state.MoveCursor(_)
        | state.ChangePage(_)
        | state.GoHome
        | state.GoEnd
        | state.ToggleSelection
        | state.SearchChanged(_)
        | state.StartDownload
        | state.ConfirmVersion
        | state.GoBack -> #(model, [])
      }
    state.Browse | state.SelectVersion(..) -> update_inner(model, msg)
  }
}

fn update_inner(
  model: state.Model,
  msg: state.Msg,
) -> #(state.Model, List(fn() -> state.Msg)) {
  case msg {
    state.Quit -> {
      process_manager.cleanup(model)
      case model.exit_subject {
        option.Some(exit) -> process.send(exit, Nil)
        option.None -> Nil
      }
      #(model, [])
    }
    state.LoaderUpdated(loader.LoaderUpdate(widgets, offset, done)) -> {
      let was_initial_loading = case model.view_mode {
        state.InitialLoading(_) -> True
        state.Browse | state.SelectVersion(..) | state.Working(_) -> False
      }
      let new_model =
        state.Model(
          ..model,
          all_widgets: widgets,
          offset: offset,
          all_loaded: done,
          view_mode: case was_initial_loading {
            True -> state.Browse
            False -> model.view_mode
          },
        )
      let new_model = case done, new_model.loader {
        False, option.None -> process_manager.start_loader(new_model)
        _, _ -> new_model
      }
      let new_model = case new_model.search_query {
        "" -> new_model
        q ->
          state.Model(
            ..new_model,
            filtered: option.Some(pagination.filter_widgets(
              new_model.all_widgets,
              q,
            )),
          )
      }
      #(new_model, [])
    }
    state.MoveCursor(delta) -> {
      case model.view_mode {
        state.Browse -> {
          let page_len = list.length(pagination.current_page_items(model))
          case page_len {
            0 -> #(model, [])
            _ -> {
              let new_cursor = int.clamp(model.cursor + delta, 0, page_len - 1)
              #(state.Model(..model, cursor: new_cursor), [])
            }
          }
        }
        state.SelectVersion(n, vs, vc, q, x, cid) -> {
          let max = int.max(0, list.length(vs) - 1)
          let new_vc = int.clamp(vc + delta, 0, max)
          #(
            state.Model(
              ..model,
              view_mode: state.SelectVersion(n, vs, new_vc, q, x, cid),
              status_msg: option.None,
            ),
            [],
          )
        }
        state.InitialLoading(_) | state.Working(_) -> #(model, [])
      }
    }
    state.ChangePage(delta) -> {
      let source_len = list.length(pagination.get_source(model))
      let max_page = case source_len {
        0 -> 0
        _ -> { source_len - 1 } / state.display_size
      }
      let new_page = model.page_index + delta
      case new_page < 0 || new_page > max_page {
        True -> #(model, [])
        False -> #(
          state.Model(
            ..model,
            page_index: new_page,
            cursor: 0,
            selected: [],
            status_msg: option.None,
          ),
          [],
        )
      }
    }
    state.GoHome -> {
      case model.view_mode {
        state.Browse -> #(state.Model(..model, cursor: 0), [])
        state.SelectVersion(n, vs, _, q, x, cid) -> #(
          state.Model(
            ..model,
            view_mode: state.SelectVersion(n, vs, 0, q, x, cid),
          ),
          [],
        )
        state.InitialLoading(_) | state.Working(_) -> #(model, [])
      }
    }
    state.GoEnd -> {
      case model.view_mode {
        state.Browse -> {
          let page_len = list.length(pagination.current_page_items(model))
          #(state.Model(..model, cursor: int.max(0, page_len - 1)), [])
        }
        state.SelectVersion(n, vs, _, q, x, cid) -> {
          let max = int.max(0, list.length(vs) - 1)
          #(
            state.Model(
              ..model,
              view_mode: state.SelectVersion(n, vs, max, q, x, cid),
            ),
            [],
          )
        }
        state.InitialLoading(_) | state.Working(_) -> #(model, [])
      }
    }
    state.ToggleSelection -> {
      let page_len = list.length(pagination.current_page_items(model))
      case model.cursor < page_len {
        False -> #(model, [])
        True -> {
          let new_selected = case list.contains(model.selected, model.cursor) {
            True -> list.filter(model.selected, fn(i) { i != model.cursor })
            False -> [model.cursor, ..model.selected]
          }
          #(state.Model(..model, selected: new_selected), [])
        }
      }
    }
    state.SearchChanged(query) -> {
      let filtered = case query {
        "" -> option.None
        _ -> option.Some(pagination.filter_widgets(model.all_widgets, query))
      }
      #(
        state.Model(
          ..model,
          search_query: query,
          filtered: filtered,
          page_index: 0,
          cursor: 0,
          selected: [],
        ),
        [],
      )
    }
    state.StartDownload -> {
      let page = pagination.current_page_items(model)
      let page_len = list.length(page)
      case page_len {
        0 -> #(model, [])
        _ -> {
          let indices = case model.selected {
            [] -> [model.cursor]
            sel -> list.sort(sel, int.compare)
          }
          let selected_widgets =
            list.filter_map(indices, fn(idx) {
              case idx >= 0 && idx < page_len {
                False -> Error(Nil)
                True ->
                  case list.drop(page, idx) |> list.first {
                    Ok(w) -> Ok(#(w.content_id, option.unwrap(w.name, "?")))
                    Error(_) -> Error(Nil)
                  }
              }
            })
          let model = process_manager.stop_loader(model)
          let model =
            state.Model(
              ..model,
              view_mode: state.Working("세션 확인 중..."),
              status_msg: option.None,
            )
          let widgets = selected_widgets
          let cmd = fn() {
            case session.ensure_session() {
              Ok(_) -> {
                let content_ids = list.map(widgets, fn(s) { s.0 })
                let result = browser.get_all_versions(content_ids)
                state.VersionInfoReady(widgets, result)
              }
              Error(msg) -> state.SessionReady(Error(msg))
            }
          }
          #(model, [cmd])
        }
      }
    }
    state.SessionReady(result) -> {
      case result {
        Ok(_) -> #(model, [])
        Error(msg) -> {
          let model = process_manager.start_loader(model)
          #(
            state.Model(
              ..model,
              view_mode: state.Browse,
              status_msg: option.Some("  세션 확인 실패: " <> error.message(msg)),
            ),
            [],
          )
        }
      }
    }
    state.VersionInfoReady(widgets, result) -> {
      case result {
        Ok(xas_data) -> enter_version_mode(model, widgets, xas_data)
        Error(msg) -> {
          let model = process_manager.start_loader(model)
          #(
            state.Model(
              ..model,
              view_mode: state.Browse,
              status_msg: option.Some("  버전 정보 조회 실패: " <> error.message(msg)),
            ),
            [],
          )
        }
      }
    }
    state.ApiVersionsReady(name, content_id, queue, xas_data, result) -> {
      case result {
        Ok(api_versions) -> {
          case api_versions {
            [] ->
              enter_version_mode(
                state.Model(
                  ..model,
                  status_msg: option.Some(
                    "  " <> name <> " — 버전 정보를 가져올 수 없습니다",
                  ),
                ),
                queue,
                xas_data,
              )
            _ -> {
              let xas_versions = case dict.get(xas_data, content_id) {
                Ok(v) -> v
                Error(_) -> []
              }
              let merged = version_merger.merge(api_versions, xas_versions)
              #(
                state.Model(
                  ..model,
                  view_mode: state.SelectVersion(
                    name,
                    merged,
                    0,
                    queue,
                    xas_data,
                    content_id,
                  ),
                  status_msg: option.None,
                ),
                [],
              )
            }
          }
        }
        Error(_) ->
          enter_version_mode(
            state.Model(
              ..model,
              status_msg: option.Some("  " <> name <> " — 버전 정보를 가져올 수 없습니다"),
            ),
            queue,
            xas_data,
          )
      }
    }
    state.ConfirmVersion -> {
      case model.view_mode {
        state.SelectVersion(
          name,
          versions,
          ver_cursor,
          queue,
          xas_data,
          content_id,
        ) -> {
          case list.drop(versions, ver_cursor) |> list.first {
            Error(_) -> #(model, [])
            Ok(selected) ->
              case selected.downloadable, selected.download_url {
                True, option.Some(url) -> {
                  let model =
                    state.Model(
                      ..model,
                      view_mode: state.Working(name <> " 다운로드 중..."),
                    )
                  let root = model.project_root
                  let version = selected.version_number
                  let react = selected.react_ready
                  let cmd = fn() {
                    let result =
                      downloader.download_and_extract(
                        url,
                        name,
                        version,
                        option.Some(content_id),
                        root,
                      )
                    case result {
                      Ok(dl) -> {
                        case
                          config.write_widget(
                            root,
                            name,
                            version,
                            option.Some(content_id),
                            option.None,
                          )
                        {
                          Error(reason) ->
                            state.DownloadDone(
                              name,
                              queue,
                              xas_data,
                              Error(reason),
                            )
                          Ok(Nil) -> {
                            let type_label = case react {
                              option.Some(True) -> " (Pluggable)"
                              option.Some(False) -> " (Classic)"
                              option.None -> ""
                            }
                            state.DownloadDone(
                              name,
                              queue,
                              xas_data,
                              Ok(
                                downloader.DownloadResult(
                                  ..dl,
                                  s3_id: "✓ "
                                    <> name
                                    <> " 다운로드 완료"
                                    <> type_label,
                                ),
                              ),
                            )
                          }
                        }
                      }
                      Error(msg) ->
                        state.DownloadDone(name, queue, xas_data, Error(msg))
                    }
                  }
                  #(model, [cmd])
                }
                False, option.None
                | False, option.Some(_)
                | True, option.None
                -> #(
                  state.Model(
                    ..model,
                    status_msg: option.Some(
                      "  v" <> selected.version_number <> "은 다운로드할 수 없습니다",
                    ),
                  ),
                  [],
                )
              }
          }
        }
        state.Browse | state.InitialLoading(_) | state.Working(_) -> #(
          model,
          [],
        )
      }
    }
    state.DownloadDone(_name, queue, xas_data, result) -> {
      case result {
        Ok(dl) -> {
          let model =
            state.Model(..model, status_msg: option.Some("  " <> dl.s3_id))
          enter_version_mode(model, queue, xas_data)
        }
        Error(msg) -> {
          let model =
            state.Model(
              ..model,
              status_msg: option.Some("  ✗ 다운로드 실패: " <> error.message(msg)),
            )
          enter_version_mode(model, queue, xas_data)
        }
      }
    }
    state.GoBack -> {
      case model.view_mode {
        state.SelectVersion(..) -> {
          let model =
            process_manager.start_loader(
              state.Model(
                ..model,
                view_mode: state.Browse,
                status_msg: option.None,
              ),
            )
          #(model, [])
        }
        state.Browse | state.InitialLoading(_) | state.Working(_) -> #(
          model,
          [],
        )
      }
    }
  }
}

fn enter_version_mode(
  model: state.Model,
  widgets: List(#(Int, String)),
  xas_data: dict.Dict(Int, List(xas_parser.XasVersion)),
) -> #(state.Model, List(fn() -> state.Msg)) {
  case widgets {
    [] -> {
      let model =
        process_manager.start_loader(
          state.Model(..model, view_mode: state.Browse, selected: []),
        )
      #(model, [])
    }
    [#(cid, name), ..rest] -> {
      let model_pat = model.pat
      let model =
        state.Model(..model, view_mode: state.Working(name <> " 버전 조회 중..."))
      let cmd = fn() {
        state.ApiVersionsReady(
          name,
          cid,
          rest,
          xas_data,
          content_transport.fetch_versions(model_pat, cid),
        )
      }
      #(model, [cmd])
    }
  }
}
