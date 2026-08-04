//// Resolves Marketplace metadata and package versions.
////

import gleam/dict
import gleam/list
import gleam/result
import mxpak/browser
import mxpak/error
import mxpak/registry/content_api
import mxpak/registry/content_transport
import mxpak/registry/version_merger
import mxpak/registry/xas_parser

/// Fetches the widgets.
pub fn fetch_widgets(
  pat pat: String,
  offset offset: Int,
  limit limit: Int,
) -> Result(content_api.ContentPage, error.Error) {
  content_transport.fetch_content_page(pat, offset, limit)
}

/// Fetches the versions.
pub fn fetch_versions(
  pat pat: String,
  content_id content_id: Int,
) -> Result(List(content_api.ContentApiVersion), error.Error) {
  content_transport.fetch_versions(pat, content_id)
}

/// Collects the xas versions.
pub fn collect_xas_versions(
  content_ids content_ids: List(Int),
) -> Result(dict.Dict(Int, List(xas_parser.XasVersion)), error.Error) {
  browser.get_all_versions(content_ids)
}

/// Fetches the merged versions.
pub fn fetch_merged_versions(
  pat pat: String,
  content_id content_id: Int,
  xas_versions xas_versions: List(xas_parser.XasVersion),
) -> Result(List(version_merger.MergedVersion), error.Error) {
  use api_versions <- result.try(content_transport.fetch_versions(
    pat,
    content_id,
  ))
  Ok(version_merger.merge(api_versions, xas_versions))
}

/// Fetches the all merged versions.
pub fn fetch_all_merged_versions(
  pat pat: String,
  content_ids content_ids: List(Int),
) -> Result(dict.Dict(Int, List(version_merger.MergedVersion)), error.Error) {
  use xas_map <- result.try(browser.get_all_versions(content_ids))
  list.try_fold(content_ids, dict.new(), fn(acc, cid) {
    let xas = case dict.get(xas_map, cid) {
      Ok(v) -> v
      Error(_) -> []
    }
    use merged <- result.try(fetch_merged_versions(pat, cid, xas))
    Ok(dict.insert(acc, cid, merged))
  })
}
