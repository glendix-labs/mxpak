//// Sends Sans-IO Marketplace Content API requests with the package runtime.
////
//// Network transport stays outside the Content API module so request creation
//// and response decoding remain deterministic and directly testable.

import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/result
import gleam/string
import mxpak/error
import mxpak/registry/content_api

/// Sends one request using the Erlang HTTP client configuration shared by the CLI.
pub fn send(
  request http_request: request.Request(String),
) -> Result(response.Response(String), error.Error) {
  let configuration =
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.timeout(30_000)
  httpc.dispatch(configuration, http_request)
  |> result.map_error(fn(reason) {
    error.registry("Content API transport failed: " <> string.inspect(reason))
  })
}

/// Fetches and decodes one Marketplace content page.
pub fn fetch_content_page(
  with pat: String,
  from offset: Int,
  limit limit: Int,
) -> Result(content_api.ContentPage, error.Error) {
  use request <- result.try(
    content_api.content_page_request(pat, offset, limit)
    |> result.map_error(content_api_error),
  )
  use response <- result.try(send(request))
  content_api.content_page_response(response)
  |> result.map_error(content_api_error)
}

/// Fetches and decodes every version for one Marketplace content item.
pub fn fetch_versions(
  with pat: String,
  for content_id: Int,
) -> Result(List(content_api.ContentApiVersion), error.Error) {
  let request = content_api.versions_request(pat, content_id)
  use response <- result.try(send(request))
  content_api.versions_response(response, content_id)
  |> result.map_error(content_api_error)
}

fn content_api_error(error: content_api.ContentApiError) -> error.Error {
  error.registry(string.inspect(error))
}
