//// Builds Mendix Marketplace Content API requests and decodes their responses.
////
//// This module is Sans-IO: callers choose the HTTP client, retry policy, and
//// runtime. Each operation is represented by a request builder and a response
//// decoder.

import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

/// A Marketplace widget or module summary.
pub type Widget {
  /// Content metadata returned by the Marketplace.
  Widget(
    name: option.Option(String),
    content_id: Int,
    publisher: option.Option(String),
    latest_version: option.Option(String),
    widget_type: String,
  )
}

/// A published Marketplace version.
pub type ContentApiVersion {
  /// Version metadata returned by the Marketplace.
  ContentApiVersion(
    version_number: String,
    publication_date: option.Option(String),
    min_supported_mendix_version: option.Option(String),
    download_url: option.Option(String),
  )
}

/// A page of Marketplace content results.
pub type ContentPage {
  /// Filtered widget entries and pagination state.
  ContentPage(widgets: List(Widget), total_items: Int, all_done: Bool)
}

/// Identifies the Content API operation associated with a response.
pub type Operation {
  /// Fetching a page of widget and module summaries.
  FetchContentPage
  /// Fetching every published version for one content item.
  FetchVersions(content_id: Int)
}

/// Describes a Content API request or response failure.
pub type ContentApiError {
  /// The supplied page bounds cannot form a valid request.
  InvalidPageBounds(offset: Int, limit: Int)
  /// The Marketplace rejected the supplied personal access token.
  AuthenticationFailed(operation: Operation)
  /// The Marketplace returned a non-success status.
  UnexpectedStatus(operation: Operation, status: Int, body: String)
  /// A successful response did not match the expected JSON schema.
  InvalidResponse(operation: Operation, reason: json.DecodeError)
}

/// Number of Marketplace entries requested by the interactive clients.
pub const fetch_size = 40

/// Builds a request for one Marketplace content page.
pub fn content_page_request(
  with pat: String,
  from offset: Int,
  limit limit: Int,
) -> Result(request.Request(String), ContentApiError) {
  case offset < 0 || limit <= 0 {
    True -> Error(InvalidPageBounds(offset: offset, limit: limit))
    False ->
      Ok(
        base_request(pat)
        |> request.set_path(api_prefix <> "/content")
        |> request.set_query([
          #("limit", int.to_string(limit)),
          #("offset", int.to_string(offset)),
        ]),
      )
  }
}

/// Decodes one Marketplace content-page response.
pub fn content_page_response(
  from response: response.Response(String),
) -> Result(ContentPage, ContentApiError) {
  use body <- result.try(successful_body(response, FetchContentPage))
  json.parse(body, content_page_decoder())
  |> result.map_error(fn(reason) {
    InvalidResponse(operation: FetchContentPage, reason: reason)
  })
}

/// Builds a request for all versions of one Marketplace content item.
pub fn versions_request(
  with pat: String,
  for content_id: Int,
) -> request.Request(String) {
  base_request(pat)
  |> request.set_path(
    api_prefix <> "/content/" <> int.to_string(content_id) <> "/versions",
  )
}

/// Decodes and newest-first sorts a Marketplace versions response.
pub fn versions_response(
  from response: response.Response(String),
  for content_id: Int,
) -> Result(List(ContentApiVersion), ContentApiError) {
  let operation = FetchVersions(content_id: content_id)
  use body <- result.try(successful_body(response, operation))
  use versions <- result.try(
    json.parse(body, versions_response_decoder())
    |> result.map_error(fn(reason) {
      InvalidResponse(operation: operation, reason: reason)
    }),
  )
  Ok(sort_versions(versions))
}

const api_host = "marketplace-api.mendix.com"

const api_prefix = "/v1"

fn base_request(pat: String) -> request.Request(String) {
  request.new()
  |> request.set_host(api_host)
  |> request.set_scheme(http.Https)
  |> request.set_method(http.Get)
  |> request.set_header("authorization", "MxToken " <> pat)
}

fn successful_body(
  response: response.Response(String),
  operation: Operation,
) -> Result(String, ContentApiError) {
  case response.status {
    status if status >= 200 && status < 300 -> Ok(response.body)
    401 -> Error(AuthenticationFailed(operation: operation))
    status ->
      Error(UnexpectedStatus(
        operation: operation,
        status: status,
        body: response.body,
      ))
  }
}

fn sort_versions(versions: List(ContentApiVersion)) -> List(ContentApiVersion) {
  list.sort(versions, fn(left, right) {
    let left_date = option.unwrap(left.publication_date, "")
    let right_date = option.unwrap(right.publication_date, "")
    string.compare(right_date, left_date)
  })
}

fn content_page_decoder() -> decode.Decoder(ContentPage) {
  use items <- decode.field("items", decode.list(widget_decoder()))
  let widgets =
    list.filter(items, fn(widget) {
      widget.widget_type == "Widget" || widget.widget_type == "Module"
    })
  let all_done = list.length(items) < fetch_size
  decode.success(ContentPage(
    widgets: widgets,
    total_items: list.length(items),
    all_done: all_done,
  ))
}

fn widget_decoder() -> decode.Decoder(Widget) {
  use content_id <- decode.field("contentId", decode.int)
  use widget_type <- decode.field("type", decode.string)
  use publisher <- decode.optional_field(
    "publisher",
    option.None,
    decode.optional(decode.string),
  )
  use latest_version <- decode.optional_field(
    "latestVersion",
    option.None,
    decode.optional(latest_version_decoder()),
  )
  let name = case latest_version {
    option.Some(#(name, _)) -> name
    option.None -> option.None
  }
  let version_number = case latest_version {
    option.Some(#(_, version_number)) -> version_number
    option.None -> option.None
  }
  decode.success(Widget(
    name: name,
    content_id: content_id,
    publisher: publisher,
    latest_version: version_number,
    widget_type: widget_type,
  ))
}

fn latest_version_decoder() -> decode.Decoder(
  #(option.Option(String), option.Option(String)),
) {
  use name <- decode.optional_field(
    "name",
    option.None,
    decode.optional(decode.string),
  )
  use version_number <- decode.optional_field(
    "versionNumber",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(#(name, version_number))
}

fn versions_response_decoder() -> decode.Decoder(List(ContentApiVersion)) {
  decode.field(
    "items",
    decode.list(content_api_version_decoder()),
    decode.success,
  )
}

fn content_api_version_decoder() -> decode.Decoder(ContentApiVersion) {
  use version_number <- decode.field("versionNumber", decode.string)
  use publication_date <- decode.optional_field(
    "publicationDate",
    option.None,
    decode.optional(decode.string),
  )
  use minimum_mendix_version <- decode.optional_field(
    "minSupportedMendixVersion",
    option.None,
    decode.optional(decode.string),
  )
  use download_url <- decode.optional_field(
    "downloadUrl",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(ContentApiVersion(
    version_number: version_number,
    publication_date: publication_date,
    min_supported_mendix_version: minimum_mendix_version,
    download_url: download_url,
  ))
}
