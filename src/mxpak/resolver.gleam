//// Resolves configured Mendix widgets into project artifacts.
////

import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import mxpak/browser
import mxpak/cache
import mxpak/config
import mxpak/config/toml_reader
import mxpak/downloader
import mxpak/error
import mxpak/lockfile
import mxpak/mpk/metadata
import mxpak/registry/content_transport
import mxpak/registry/xas_parser
import mxpak/session
import mxpak/widget
import simplifile

/// A typed `ResolveResult` value used by the resolver capability.
pub type ResolveResult {
  /// The `ResolveResult` variant.
  ResolveResult(
    name: String,
    version: String,
    content_id: option.Option(Int),
    s3_id: option.Option(String),
    hash: String,
    kind: widget.Kind,
  )
}

/// Resolves the all.
pub fn resolve_all(
  project_root project_root: String,
) -> Result(List(ResolveResult), error.Error) {
  use configuration <- result.try(config.read(project_root))
  use pat <- result.try(config.get_pat(project_root))
  case configuration.mode {
    toml_reader.Mpk -> resolve_all_mpk(project_root, configuration, pat)
    toml_reader.Extract -> resolve_all_extract(project_root, configuration, pat)
  }
}

fn resolve_all_extract(
  project_root: String,
  configuration: toml_reader.ProjectConfig,
  pat: option.Option(String),
) -> Result(List(ResolveResult), error.Error) {
  use _ <- result.try(cleanup_stale_widgets(
    project_root,
    configuration.widgets |> dict.keys,
  ))
  let widget_list = dict.to_list(configuration.widgets)
  case widget_list {
    [] -> {
      io.println_error("설치할 위젯 없음")
      Ok([])
    }
    _ ->
      list.try_fold(widget_list, [], fn(acc, pair) {
        let #(name, widget) = pair
        case resolve_single(project_root, name, widget, pat) {
          Ok(result) -> Ok([result, ..acc])
          Error(msg) -> {
            io.println_error("경고: " <> name <> " — " <> error.message(msg))
            Ok(acc)
          }
        }
      })
  }
}

fn resolve_all_mpk(
  project_root: String,
  configuration: toml_reader.ProjectConfig,
  pat: option.Option(String),
) -> Result(List(ResolveResult), error.Error) {
  let widgets_dir = project_root <> "/" <> configuration.widgets_dir
  use _ <- result.try(
    simplifile.create_directory_all(widgets_dir)
    |> result.map_error(fn(_) {
      error.resolution("위젯 디렉터리 생성 실패: " <> widgets_dir)
    }),
  )
  let lock = case lockfile.read(project_root) {
    Ok(l) -> option.Some(l)
    Error(_) -> option.None
  }
  let widget_list = dict.to_list(configuration.widgets)
  case widget_list {
    [] -> {
      io.println_error("설치할 위젯 없음")
      Ok([])
    }
    _ ->
      list.try_fold(widget_list, [], fn(acc, pair) {
        let #(name, widget) = pair
        case
          resolve_single_mpk(widgets_dir, project_root, name, widget, pat, lock)
        {
          Ok(result) -> Ok([result, ..acc])
          Error(msg) -> {
            io.println_error("경고: " <> name <> " — " <> error.message(msg))
            Ok(acc)
          }
        }
      })
  }
}

fn resolve_single_mpk(
  widgets_dir: String,
  project_root: String,
  name: String,
  widget: toml_reader.WidgetConfig,
  pat: option.Option(String),
  lock: option.Option(lockfile.Lockfile),
) -> Result(ResolveResult, error.Error) {
  let target_path = widgets_dir <> "/" <> name <> ".mpk"
  case widget.version {
    "" -> Error(error.resolution("version이 지정되지 않았습니다"))
    version -> {
      case check_mpk_installed(target_path, name, version, lock) {
        Ok(result) -> {
          io.println_error(name <> " v" <> version <> " — 이미 설치됨")
          Ok(result)
        }
        Error(_) ->
          case widget.s3_id {
            option.Some(s3_id) ->
              download_mpk_with_s3(target_path, name, version, widget.id, s3_id)
            option.None ->
              resolve_mpk_via_api(
                target_path,
                project_root,
                name,
                version,
                widget.id,
                pat,
              )
          }
      }
    }
  }
}

fn check_mpk_installed(
  target_path: String,
  name: String,
  version: String,
  lock: option.Option(lockfile.Lockfile),
) -> Result(ResolveResult, error.Error) {
  case simplifile.is_file(target_path) {
    Ok(True) ->
      case lock {
        option.Some(lf) ->
          case lockfile.get_entry(lf, name) {
            Ok(entry) ->
              case entry.version == version {
                True ->
                  Ok(ResolveResult(
                    name: name,
                    version: version,
                    content_id: entry.content_id,
                    s3_id: entry.s3_id,
                    hash: entry.hash,
                    kind: entry.kind,
                  ))
                False -> Error(error.resolution("버전 불일치"))
              }
            Error(_) -> Error(error.resolution("락파일 엔트리 없음"))
          }
        option.None -> Error(error.resolution("락파일 없음"))
      }
    _ -> {
      case lock {
        option.Some(lf) ->
          case lockfile.get_entry(lf, name) {
            Ok(entry) ->
              case entry.version == version && entry.hash != "" {
                True ->
                  case cache.restore_mpk(entry.hash, target_path) {
                    Ok(_) -> {
                      io.println_error(name <> " v" <> version <> " — 캐시에서 복원")
                      Ok(ResolveResult(
                        name: name,
                        version: version,
                        content_id: entry.content_id,
                        s3_id: entry.s3_id,
                        hash: entry.hash,
                        kind: entry.kind,
                      ))
                    }
                    Error(_) -> Error(error.resolution("캐시 복원 실패"))
                  }
                False -> Error(error.resolution("버전 불일치"))
              }
            Error(_) -> Error(error.resolution("락파일 엔트리 없음"))
          }
        option.None -> Error(error.resolution("파일 없음"))
      }
    }
  }
}

fn download_mpk_with_s3(
  target_path: String,
  name: String,
  version: String,
  content_id: option.Option(Int),
  s3_id: String,
) -> Result(ResolveResult, error.Error) {
  let url = "https://files.appstore.mendix.com/" <> s3_id
  use dl <- result.try(downloader.download_mpk(
    url,
    name,
    version,
    content_id,
    target_path,
  ))
  Ok(ResolveResult(
    name: name,
    version: version,
    content_id: content_id,
    s3_id: option.Some(s3_id),
    hash: dl.hash,
    kind: dl.kind,
  ))
}

fn resolve_mpk_via_api(
  target_path: String,
  project_root: String,
  name: String,
  version: String,
  content_id: option.Option(Int),
  pat: option.Option(String),
) -> Result(ResolveResult, error.Error) {
  use pat_val <- require_pat(pat)
  use cid <- result.try(case content_id {
    option.Some(id) -> Ok(id)
    option.None -> {
      use page <- result.try(content_transport.fetch_content_page(
        pat_val,
        0,
        40,
      ))
      case list.find(page.widgets, fn(w) { w.name == option.Some(name) }) {
        Ok(w) -> {
          use _ <- result.try(config.write_widget(
            project_root,
            name,
            version,
            option.Some(w.content_id),
            option.None,
          ))
          Ok(w.content_id)
        }
        Error(_) -> Error(error.resolution("'" <> name <> "' 위젯을 찾을 수 없습니다"))
      }
    }
  })
  use _ <- result.try(session.ensure_session())
  use xas_versions <- result.try(
    mxpak_browser_get_versions(cid)
    |> result.map_error(fn(_) { error.resolution("XAS 버전 수집 실패") }),
  )
  case list.find(xas_versions, fn(xas) { xas.version_number == version }) {
    Ok(xas) -> {
      use _ <- result.try(config.write_widget(
        project_root,
        name,
        version,
        option.Some(cid),
        option.Some(xas.s3_object_id),
      ))
      download_mpk_with_s3(
        target_path,
        name,
        version,
        option.Some(cid),
        xas.s3_object_id,
      )
    }
    Error(_) ->
      Error(error.resolution(
        "v" <> version <> " s3_id를 찾을 수 없습니다 (id=" <> int.to_string(cid) <> ")",
      ))
  }
}

fn resolve_single(
  project_root: String,
  name: String,
  widget: toml_reader.WidgetConfig,
  pat: option.Option(String),
) -> Result(ResolveResult, error.Error) {
  case widget.version {
    "" -> Error(error.resolution("version이 지정되지 않았습니다"))
    version -> {
      case check_cache(project_root, name, version) {
        Ok(result) -> {
          io.println_error(name <> " v" <> version <> " — 캐시 사용")
          Ok(result)
        }
        Error(_) ->
          case widget.s3_id {
            option.Some(s3_id) ->
              download_with_s3(project_root, name, version, widget.id, s3_id)
            option.None ->
              resolve_via_api(project_root, name, version, widget.id, pat)
          }
      }
    }
  }
}

fn check_cache(
  project_root: String,
  name: String,
  version: String,
) -> Result(ResolveResult, error.Error) {
  let cache_dir = project_root <> "/build/widgets/" <> name
  let meta_path = cache_dir <> "/meta.toml"
  use meta <- result.try(metadata.read(meta_path))
  case meta.version == version {
    True -> {
      case has_widget_files(cache_dir, meta.kind) {
        True ->
          Ok(ResolveResult(
            name: name,
            version: version,
            content_id: meta.id,
            s3_id: meta.s3_id,
            hash: "",
            kind: meta.kind,
          ))
        False -> Error(error.resolution("캐시 파일 불완전"))
      }
    }
    False -> Error(error.resolution("버전 불일치"))
  }
}

fn has_widget_files(cache_dir: String, kind: widget.Kind) -> Bool {
  case simplifile.read_directory(cache_dir) {
    Ok(files) ->
      case kind {
        widget.Classic -> True
        widget.Pluggable ->
          list.any(files, fn(f) {
            string.ends_with(f, ".xml") && f != "package.xml"
          })
      }
    Error(_) -> False
  }
}

fn download_with_s3(
  project_root: String,
  name: String,
  version: String,
  content_id: option.Option(Int),
  s3_id: String,
) -> Result(ResolveResult, error.Error) {
  let url = "https://files.appstore.mendix.com/" <> s3_id
  use dl <- result.try(downloader.download_and_extract(
    url,
    name,
    version,
    content_id,
    project_root,
  ))
  Ok(ResolveResult(
    name: name,
    version: version,
    content_id: content_id,
    s3_id: option.Some(s3_id),
    hash: dl.hash,
    kind: dl.kind,
  ))
}

fn resolve_via_api(
  project_root: String,
  name: String,
  version: String,
  content_id: option.Option(Int),
  pat: option.Option(String),
) -> Result(ResolveResult, error.Error) {
  use pat_val <- require_pat(pat)
  use cid <- result.try(case content_id {
    option.Some(id) -> Ok(id)
    option.None -> {
      use page <- result.try(content_transport.fetch_content_page(
        pat_val,
        0,
        40,
      ))
      case list.find(page.widgets, fn(w) { w.name == option.Some(name) }) {
        Ok(w) -> {
          use _ <- result.try(config.write_widget(
            project_root,
            name,
            version,
            option.Some(w.content_id),
            option.None,
          ))
          Ok(w.content_id)
        }
        Error(_) -> Error(error.resolution("'" <> name <> "' 위젯을 찾을 수 없습니다"))
      }
    }
  })
  use _ <- result.try(session.ensure_session())
  use xas_versions <- result.try(
    mxpak_browser_get_versions(cid)
    |> result.map_error(fn(_) { error.resolution("XAS 버전 수집 실패") }),
  )
  case list.find(xas_versions, fn(xas) { xas.version_number == version }) {
    Ok(xas) -> {
      use _ <- result.try(config.write_widget(
        project_root,
        name,
        version,
        option.Some(cid),
        option.Some(xas.s3_object_id),
      ))
      download_with_s3(
        project_root,
        name,
        version,
        option.Some(cid),
        xas.s3_object_id,
      )
    }
    Error(_) ->
      Error(error.resolution(
        "v" <> version <> " s3_id를 찾을 수 없습니다 (id=" <> int.to_string(cid) <> ")",
      ))
  }
}

fn require_pat(
  pat: option.Option(String),
  cont: fn(String) -> Result(ResolveResult, error.Error),
) -> Result(ResolveResult, error.Error) {
  case pat {
    option.Some(val) -> cont(val)
    option.None -> Error(error.resolution("PAT 필요: .env에 MENDIX_PAT를 설정하세요"))
  }
}

fn cleanup_stale_widgets(
  project_root: String,
  current_names: List(String),
) -> Result(Nil, error.Error) {
  let widgets_dir = project_root <> "/build/widgets"
  case simplifile.read_directory(widgets_dir) {
    Ok(dirs) ->
      list.try_each(dirs, fn(dir) {
        case list.contains(current_names, dir) {
          True -> Ok(Nil)
          False ->
            simplifile.delete(widgets_dir <> "/" <> dir)
            |> result.map_error(fn(_) {
              error.resolution("오래된 위젯 삭제 실패: " <> dir)
            })
        }
      })
    Error(simplifile.Enoent) -> Ok(Nil)
    Error(_) -> Error(error.resolution("위젯 디렉터리 읽기 실패: " <> widgets_dir))
  }
}

fn mxpak_browser_get_versions(
  content_id: Int,
) -> Result(List(xas_parser.XasVersion), error.Error) {
  browser.get_versions_for(content_id)
}
