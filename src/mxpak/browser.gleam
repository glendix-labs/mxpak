//// Provides browser operations for mxpak.
////

import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import glendam
import glendam/chrome
import glendam/network_idle
import glendam/network_listener
import glendam/protocol/page
import glendam/protocol/runtime
import mxpak/error
import mxpak/registry/xas_parser

/// Collects versions for all supplied content identifiers.
pub fn get_all_versions(
  content_ids content_ids: List(Int),
) -> Result(dict.Dict(Int, List(xas_parser.XasVersion)), error.Error) {
  use browser <- result.try(
    glendam.launch()
    |> result.map_error(fn(_) { error.browser("브라우저 시작 실패") }),
  )
  let results =
    list.fold(content_ids, dict.new(), fn(acc, content_id) {
      let versions = collect_versions_for_id(browser, content_id)
      dict.insert(acc, content_id, versions)
    })
  use _ <- result.try(
    glendam.quit(browser)
    |> result.map_error(fn(error) {
      error.browser("브라우저 종료 실패: " <> string.inspect(error))
    }),
  )
  Ok(results)
}

/// Collects versions for one content identifier.
pub fn get_versions_for(
  content_id content_id: Int,
) -> Result(List(xas_parser.XasVersion), error.Error) {
  use browser <- result.try(
    glendam.launch()
    |> result.map_error(fn(_) { error.browser("브라우저 시작 실패") }),
  )
  let versions = collect_versions_for_id(browser, content_id)
  use _ <- result.try(
    glendam.quit(browser)
    |> result.map_error(fn(error) {
      error.browser("브라우저 종료 실패: " <> string.inspect(error))
    }),
  )
  Ok(versions)
}

fn collect_versions_for_id(
  browser: process.Subject(chrome.Message),
  content_id: Int,
) -> List(xas_parser.XasVersion) {
  let url =
    "https://marketplace.mendix.com/link/component/"
    <> int.to_string(content_id)
  case collect_versions_impl(browser, url) {
    Ok(versions) -> versions
    Error(msg) -> {
      io.println_error(
        "  [mxpak] 오류 (id="
        <> int.to_string(content_id)
        <> "): "
        <> error.message(msg),
      )
      []
    }
  }
}

fn collect_versions_impl(
  browser: process.Subject(chrome.Message),
  url: String,
) -> Result(List(xas_parser.XasVersion), error.Error) {
  use page <- result.try(
    glendam.open(browser, "about:blank", 30_000)
    |> result.map_error(fn(_) { error.browser("페이지 생성 실패") }),
  )
  let result = {
    use response_listener <- result.try(
      network_listener.start(page)
      |> result.map_error(fn(_) { error.browser("network listener 시작 실패") }),
    )
    let inner_result = {
      use idle_listener <- result.try(
        network_idle.start(page)
        |> result.map_error(fn(_) {
          error.browser("network idle listener 시작 실패")
        }),
      )
      let caller = glendam.page_caller(page)
      use _ <- result.try(
        page.navigate(
          caller,
          url: url,
          referrer: option.None,
          transition_type: option.None,
          frame_id: option.None,
        )
        |> result.map_error(fn(_) { error.browser("네비게이션 실패") }),
      )
      use _ <- result.try(
        network_idle.wait_for_idle(
          idle_listener,
          quiet_ms: 500,
          time_out: 30_000,
        )
        |> result.map_error(fn(error) {
          error.browser("network idle 대기 실패: " <> string.inspect(error))
        }),
      )
      network_idle.stop(idle_listener)
      try_click_releases_tab(page)
      case network_idle.start(page) {
        Ok(idle2) -> {
          case
            network_idle.wait_for_idle(idle2, quiet_ms: 500, time_out: 30_000)
          {
            Ok(Nil) -> Nil
            Error(error) ->
              io.println_error(
                "  [mxpak] 추가 network idle 대기 실패: " <> string.inspect(error),
              )
          }
          network_idle.stop(idle2)
        }
        Error(_) -> Nil
      }
      process.sleep(3000)
      use xas_responses <- result.try(
        network_listener.collect_responses(response_listener, filter: fn(event) {
          string.contains(event.response.url, "/xas/")
        })
        |> result.map_error(fn(reason) {
          error.browser(
            "network response collection failed: " <> string.inspect(reason),
          )
        }),
      )
      let versions =
        list.flat_map(xas_responses, fn(resp) {
          xas_parser.parse_xas_body(resp.body)
        })
      Ok(deduplicate_versions(versions))
    }
    network_listener.stop(response_listener)
    inner_result
  }
  case result, glendam.close(page) {
    Error(error), Ok(_) | Error(error), Error(_) -> Error(error)
    Ok(value), Ok(_) -> Ok(value)
    Ok(_), Error(error) ->
      Error(error.browser("페이지 닫기 실패: " <> string.inspect(error)))
  }
}

fn deduplicate_versions(
  versions: List(xas_parser.XasVersion),
) -> List(xas_parser.XasVersion) {
  list.fold(versions, #([], dict.new()), fn(acc, v) {
    let #(result_list, seen) = acc
    case dict.has_key(seen, v.s3_object_id) {
      True -> acc
      False -> #(
        list.append(result_list, [v]),
        dict.insert(seen, v.s3_object_id, True),
      )
    }
  }).0
}

fn try_click_releases_tab(page: glendam.Page) -> Nil {
  case glendam.click_selector(on: page, target: "a.mx-name-tabPage10") {
    Ok(_) -> Nil
    Error(_) -> {
      case try_click_tab_by_text(page) {
        Ok(_) -> Nil
        Error(_) -> {
          case
            glendam.eval(
              on: page,
              js: "(() => { const tabs = document.querySelectorAll('a[role=\"tab\"]'); for (const t of tabs) { if (t.textContent.includes('Releases')) { t.click(); return true; } } return false; })()",
            )
          {
            Ok(_) -> Nil
            Error(reason) ->
              io.println_error(
                "  [mxpak] Releases 탭 클릭 실패: " <> string.inspect(reason),
              )
          }
        }
      }
    }
  }
}

fn try_click_tab_by_text(
  page: glendam.Page,
) -> Result(Nil, chrome.RequestError) {
  use tabs <- result.try(glendam.select_all(
    on: page,
    matching: "a[role=\"tab\"]",
  ))
  find_and_click_releases(page, tabs)
}

fn find_and_click_releases(
  page: glendam.Page,
  tabs: List(runtime.RemoteObjectId),
) -> Result(Nil, chrome.RequestError) {
  case tabs {
    [] -> Error(chrome.NotFoundError)
    [tab, ..rest] -> {
      case glendam.get_text(on: page, from: tab) {
        Ok(text) -> {
          case string.contains(text, "Releases") {
            True ->
              glendam.click(on: page, target: tab)
              |> result.map(fn(_) { Nil })
            False -> find_and_click_releases(page, rest)
          }
        }
        Error(_) -> find_and_click_releases(page, rest)
      }
    }
  }
}
