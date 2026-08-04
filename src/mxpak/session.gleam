//// Establishes and validates Mendix browser sessions for mxpak.
////

import gleam/result
import gleam/string
import gleam_rover
import gleam_rover/page
import mxpak/error

/// Ensures a valid Mendix browser session exists.
pub fn ensure_session() -> Result(Nil, error.Error) {
  case validate_profile_session() |> result.unwrap(False) {
    True -> Ok(Nil)
    False -> interactive_login()
  }
}

/// Reports whether the saved Mendix session is valid.
pub fn is_valid() -> Result(Bool, error.Error) {
  validate_profile_session()
}

fn validate_profile_session() -> Result(Bool, error.Error) {
  use browser <- result.try(
    gleam_rover.launch()
    |> result.map_error(fn(e) {
      error.session("브라우저 시작 실패: " <> string.inspect(e))
    }),
  )
  let result = {
    use page <- result.try(
      gleam_rover.open(browser, "https://home.mendix.com/", 30_000)
      |> result.map_error(fn(e) {
        error.session("페이지 열기 실패: " <> string.inspect(e))
      }),
    )
    use _ <- result.try(
      page.wait_for_url(
        page: gleam_rover.with_timeout(page, 30_000),
        matching: fn(url) { url != "about:blank" },
        time_out: 30_000,
      )
      |> result.map_error(fn(e) {
        error.session("페이지 로드 대기 실패: " <> string.inspect(e))
      }),
    )
    use _ <- result.try(
      gleam_rover.await_selector(
        on: gleam_rover.with_timeout(page, 30_000),
        select: "body",
      )
      |> result.map_error(fn(e) {
        error.session("페이지 렌더링 대기 실패: " <> string.inspect(e))
      }),
    )
    use url <- result.try(
      page.get_url(page)
      |> result.map_error(fn(e) {
        error.session("URL 확인 실패: " <> string.inspect(e))
      }),
    )
    Ok(string.contains(url, "home.mendix"))
  }
  case result, gleam_rover.quit(browser) {
    Error(error), Ok(_) | Error(error), Error(_) -> Error(error)
    Ok(value), Ok(_) -> Ok(value)
    Ok(_), Error(error) ->
      Error(error.session("브라우저 종료 실패: " <> string.inspect(error)))
  }
}

fn interactive_login() -> Result(Nil, error.Error) {
  use browser <- result.try(
    gleam_rover.launch_window()
    |> result.map_error(fn(e) {
      error.session("visible 브라우저 시작 실패: " <> string.inspect(e))
    }),
  )
  let result = {
    use page <- result.try(
      gleam_rover.open(browser, "https://login.mendix.com/", 30_000)
      |> result.map_error(fn(e) {
        error.session("로그인 페이지 열기 실패: " <> string.inspect(e))
      }),
    )
    use _ <- result.try(
      page.wait_for_url(
        page: gleam_rover.with_timeout(page, 300_000),
        matching: fn(url) { string.starts_with(url, "https://home.mendix.com") },
        time_out: 300_000,
      )
      |> result.map_error(fn(e) {
        error.session("로그인 타임아웃 (5분): " <> string.inspect(e))
      }),
    )
    Ok(Nil)
  }
  case result, gleam_rover.quit(browser) {
    Error(error), Ok(_) | Error(error), Error(_) -> Error(error)
    Ok(value), Ok(_) -> Ok(value)
    Ok(_), Error(error) ->
      Error(error.session("브라우저 종료 실패: " <> string.inspect(error)))
  }
}
