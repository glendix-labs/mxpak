//// Tests registry behavior for mxpak.
////

import gleam/http/response
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleeunit/should
import mxpak/registry/content_api
import mxpak/registry/version_merger
import mxpak/registry/xas_parser

/// Verifies the Sans-IO request builder preserves authentication and pagination.
pub fn content_page_request_contract_test() -> Nil {
  let request =
    content_api.content_page_request("secret", 40, 20)
    |> should.be_ok
  request.host
  |> should.equal("marketplace-api.mendix.com")
  request.path
  |> should.equal("/v1/content")
  request.query
  |> should.equal(option.Some("limit=20&offset=40"))
  request.headers
  |> list.key_find("authorization")
  |> should.equal(Ok("MxToken secret"))
}

/// Verifies full pages with non-widget content continue pagination.
pub fn content_page_response_full_mixed_page_test() -> Nil {
  let body =
    "{\"items\":[{\"contentId\":0,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget0\",\"versionNumber\":\"1.0.0\"}},{\"contentId\":1,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget1\",\"versionNumber\":\"1.0.1\"}},{\"contentId\":2,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget2\",\"versionNumber\":\"1.0.2\"}},{\"contentId\":3,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget3\",\"versionNumber\":\"1.0.3\"}},{\"contentId\":4,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget4\",\"versionNumber\":\"1.0.4\"}},{\"contentId\":5,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget5\",\"versionNumber\":\"1.0.5\"}},{\"contentId\":6,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget6\",\"versionNumber\":\"1.0.6\"}},{\"contentId\":7,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget7\",\"versionNumber\":\"1.0.7\"}},{\"contentId\":8,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget8\",\"versionNumber\":\"1.0.8\"}},{\"contentId\":9,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget9\",\"versionNumber\":\"1.0.9\"}},{\"contentId\":10,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget10\",\"versionNumber\":\"1.0.10\"}},{\"contentId\":11,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget11\",\"versionNumber\":\"1.0.11\"}},{\"contentId\":12,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget12\",\"versionNumber\":\"1.0.12\"}},{\"contentId\":13,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget13\",\"versionNumber\":\"1.0.13\"}},{\"contentId\":14,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget14\",\"versionNumber\":\"1.0.14\"}},{\"contentId\":15,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget15\",\"versionNumber\":\"1.0.15\"}},{\"contentId\":16,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget16\",\"versionNumber\":\"1.0.16\"}},{\"contentId\":17,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget17\",\"versionNumber\":\"1.0.17\"}},{\"contentId\":18,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget18\",\"versionNumber\":\"1.0.18\"}},{\"contentId\":19,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget19\",\"versionNumber\":\"1.0.19\"}},{\"contentId\":20,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget20\",\"versionNumber\":\"1.0.20\"}},{\"contentId\":21,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget21\",\"versionNumber\":\"1.0.21\"}},{\"contentId\":22,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget22\",\"versionNumber\":\"1.0.22\"}},{\"contentId\":23,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget23\",\"versionNumber\":\"1.0.23\"}},{\"contentId\":24,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Widget24\",\"versionNumber\":\"1.0.24\"}},{\"contentId\":100,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":101,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":102,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":103,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":104,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":105,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":106,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":107,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":108,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":109,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":110,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":111,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":112,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":113,\"type\":\"Theme\",\"publisher\":\"Glendix\"},{\"contentId\":114,\"type\":\"Theme\",\"publisher\":\"Glendix\"}]}"
  let page =
    response.Response(status: 200, headers: [], body: body)
    |> content_api.content_page_response
    |> should.be_ok
  page.total_items
  |> should.equal(40)
  page.widgets
  |> list.length
  |> should.equal(25)
  page.all_done
  |> should.be_false
  Nil
}

/// Verifies invalid pagination is rejected before any network transport runs.
pub fn content_page_request_invalid_bounds_test() -> Nil {
  content_api.content_page_request("secret", -1, 0)
  |> should.equal(Error(content_api.InvalidPageBounds(offset: -1, limit: 0)))
}

/// Verifies hostile tokens stay inert request data instead of shell input.
pub fn hostile_pat_is_carried_verbatim_test() -> Nil {
  let hostile = "$(touch /tmp/mendraw-pwned)`id`'a\"b&whoami"
  let request =
    content_api.content_page_request(hostile, 0, 40)
    |> should.be_ok
  request.headers
  |> list.key_find("authorization")
  |> should.equal(Ok("MxToken " <> hostile))
  let versions_request = content_api.versions_request(hostile, 7)
  versions_request.headers
  |> list.key_find("authorization")
  |> should.equal(Ok("MxToken " <> hostile))
  Nil
}

/// Verifies the Sans-IO response decoder filters unsupported content types.
pub fn content_page_response_contract_test() -> Nil {
  let body =
    "{\"items\":[{\"contentId\":1,\"type\":\"Widget\",\"publisher\":\"Glendix\",\"latestVersion\":{\"name\":\"Clock\",\"versionNumber\":\"1.0.0\"}},{\"contentId\":2,\"type\":\"Theme\",\"publisher\":\"Glendix\"}]}"
  let page =
    response.Response(status: 200, headers: [], body: body)
    |> content_api.content_page_response
    |> should.be_ok
  page.total_items
  |> should.equal(2)
  page.widgets
  |> list.length
  |> should.equal(1)
  page.all_done
  |> should.be_true
}

/// Verifies versions are decoded in newest-publication-first order.
pub fn versions_response_sorting_test() -> Nil {
  let body =
    "{\"items\":[{\"versionNumber\":\"1.0.0\",\"publicationDate\":\"2024-01-01\"},{\"versionNumber\":\"2.0.0\",\"publicationDate\":\"2026-01-01\"}]}"
  let versions =
    response.Response(status: 200, headers: [], body: body)
    |> content_api.versions_response(7)
    |> should.be_ok
  let newest = versions |> list.first |> should.be_ok
  newest.version_number
  |> should.equal("2.0.0")
}

/// Verifies authentication failures retain the operation that was attempted.
pub fn versions_response_authentication_error_test() -> Nil {
  response.Response(status: 401, headers: [], body: "unauthorized")
  |> content_api.versions_response(7)
  |> should.equal(
    Error(
      content_api.AuthenticationFailed(operation: content_api.FetchVersions(
        content_id: 7,
      )),
    ),
  )
}

/// Verifies parse xas body valid behavior.
pub fn parse_xas_body_valid_test() -> Nil {
  let body =
    "{\"objects\":[{\"objectType\":\"AppStore.Version\",\"attributes\":{\"S3ObjectId\":{\"value\":\"widgets/abc/1.0.0/Widget.mpk\"},\"IsReactClientReady\":{\"value\":true},\"PublishDate\":{\"value\":\"2024-01-15\"},\"DisplayVersionNumber\":{\"value\":\"1.0.0\"}}}]}"
  let versions = xas_parser.parse_xas_body(body)
  list.length(versions)
  |> should.equal(1)
  let v =
    list.first(versions)
    |> should.be_ok
  { v.s3_object_id == "widgets/abc/1.0.0/Widget.mpk" }
  |> should.be_true
  { v.react_ready == True }
  |> should.be_true
  { v.version_number == "1.0.0" }
  |> should.be_true
  Nil
}

/// Verifies parse xas body non version objects behavior.
pub fn parse_xas_body_non_version_objects_test() -> Nil {
  let body =
    "{\"objects\":[{\"objectType\":\"AppStore.Other\",\"attributes\":{}},{\"objectType\":\"AppStore.Version\",\"attributes\":{\"S3ObjectId\":{\"value\":\"test/path\"}}}]}"
  let versions = xas_parser.parse_xas_body(body)
  list.length(versions)
  |> should.equal(1)
  let v =
    list.first(versions)
    |> should.be_ok
  { v.s3_object_id == "test/path" }
  |> should.be_true
  Nil
}

/// Verifies parse xas body invalid json behavior.
pub fn parse_xas_body_invalid_json_test() -> Nil {
  xas_parser.parse_xas_body("not json")
  |> should.equal([])
  Nil
}

/// Verifies parse xas body missing s3 behavior.
pub fn parse_xas_body_missing_s3_test() -> Nil {
  let body =
    "{\"objects\":[{\"objectType\":\"AppStore.Version\",\"attributes\":{\"PublishDate\":{\"value\":\"2024-01-01\"}}}]}"
  xas_parser.parse_xas_body(body)
  |> should.equal([])
  Nil
}

/// Verifies encode version behavior.
pub fn encode_version_test() -> Nil {
  let v =
    xas_parser.XasVersion(
      s3_object_id: "a/b/1.0/W.mpk",
      react_ready: True,
      publish_date: "2024-03-01",
      version_number: "1.0.0",
    )
  let encoded = json.to_string(xas_parser.encode_version(v))
  {
    encoded
    |> contains("\"s3ObjectId\":\"a/b/1.0/W.mpk\"")
  }
  |> should.be_true
  {
    encoded
    |> contains("\"reactReady\":true")
  }
  |> should.be_true
  Nil
}

/// Verifies merge exact match behavior.
pub fn merge_exact_match_test() -> Nil {
  let api = [
    content_api.ContentApiVersion(
      "1.0.0",
      option.Some("2024-01-01"),
      option.Some("10.0.0"),
      option.None,
    ),
  ]
  let xas = [
    xas_parser.XasVersion("w/id/1.0.0/W.mpk", True, "2024-01-01", "1.0.0"),
  ]
  let merged = version_merger.merge(api, xas)
  list.length(merged)
  |> should.equal(1)
  let v =
    list.first(merged)
    |> should.be_ok
  { v.downloadable == True }
  |> should.be_true
  v.download_url
  |> should.equal(option.Some(
    "https://files.appstore.mendix.com/w/id/1.0.0/W.mpk",
  ))
  v.react_ready
  |> should.equal(option.Some(True))
  Nil
}

/// Verifies merge s3 template fallback behavior.
pub fn merge_s3_template_fallback_test() -> Nil {
  let api = [
    content_api.ContentApiVersion(
      "2.0.0",
      option.None,
      option.None,
      option.None,
    ),
    content_api.ContentApiVersion(
      "1.0.0",
      option.None,
      option.None,
      option.None,
    ),
  ]
  let xas = [
    xas_parser.XasVersion("prefix/id/1.0.0/Widget.mpk", False, "", "1.0.0"),
  ]
  let merged = version_merger.merge(api, xas)
  list.length(merged)
  |> should.equal(2)
  let v2 =
    list.first(merged)
    |> should.be_ok
  { v2.downloadable == True }
  |> should.be_true
  v2.download_url
  |> should.equal(option.Some(
    "https://files.appstore.mendix.com/prefix/id/2.0.0/Widget.mpk",
  ))
  Nil
}

/// Verifies merge no xas data behavior.
pub fn merge_no_xas_data_test() -> Nil {
  let api = [
    content_api.ContentApiVersion(
      "1.0.0",
      option.None,
      option.None,
      option.None,
    ),
  ]
  let merged = version_merger.merge(api, [])
  list.length(merged)
  |> should.equal(1)
  let v =
    list.first(merged)
    |> should.be_ok
  v.downloadable
  |> should.be_false
  v.download_url
  |> should.be_none
  Nil
}

fn contains(haystack: String, needle: String) -> Bool {
  string.contains(haystack, needle)
}
