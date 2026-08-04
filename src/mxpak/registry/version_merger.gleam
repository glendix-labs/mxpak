//// Provides version merger operations for mxpak.
////

import gleam/dict
import gleam/list
import gleam/option
import gleam/string
import mxpak/registry/content_api
import mxpak/registry/xas_parser

/// A typed `MergedVersion` value used by the version merger capability.
pub type MergedVersion {
  /// The `MergedVersion` variant.
  MergedVersion(
    version_number: String,
    publication_date: option.Option(String),
    min_mendix_version: option.Option(String),
    download_url: option.Option(String),
    react_ready: option.Option(Bool),
    downloadable: Bool,
  )
}

/// Merges Content API versions with XAS download metadata.
pub fn merge(
  api_versions api_versions: List(content_api.ContentApiVersion),
  xas_versions xas_versions: List(xas_parser.XasVersion),
) -> List(MergedVersion) {
  let xas_index = build_xas_index(xas_versions)
  let s3_template = extract_s3_template(xas_versions)
  list.map(api_versions, fn(api) {
    let xas = dict.get(xas_index, api.version_number) |> option.from_result
    let download_url = case api.download_url, xas, s3_template {
      option.Some(url), _, _ -> option.Some(url)
      option.None, option.Some(version), _ ->
        option.Some(
          "https://files.appstore.mendix.com/" <> version.s3_object_id,
        )
      option.None, option.None, option.Some(#(prefix, file_name)) ->
        option.Some(
          "https://files.appstore.mendix.com/"
          <> prefix
          <> "/"
          <> api.version_number
          <> "/"
          <> file_name,
        )
      option.None, option.None, option.None -> option.None
    }
    MergedVersion(
      version_number: api.version_number,
      publication_date: api.publication_date,
      min_mendix_version: api.min_supported_mendix_version,
      download_url: download_url,
      react_ready: case xas {
        option.Some(version) -> option.Some(version.react_ready)
        option.None -> option.None
      },
      downloadable: option.is_some(download_url),
    )
  })
}

fn build_xas_index(
  xas_versions: List(xas_parser.XasVersion),
) -> dict.Dict(String, xas_parser.XasVersion) {
  list.fold(xas_versions, dict.new(), fn(acc, xas) {
    let acc = case xas.version_number {
      "" -> acc
      vn -> dict.insert(acc, vn, xas)
    }
    let parts = string.split(xas.s3_object_id, "/")
    case list.length(parts) >= 4 {
      True ->
        case list.drop(parts, 2) |> list.first {
          Ok(ver) -> dict.insert(acc, ver, xas)
          Error(_) -> acc
        }
      False -> acc
    }
  })
}

fn extract_s3_template(
  xas_versions: List(xas_parser.XasVersion),
) -> option.Option(#(String, String)) {
  list.find_map(xas_versions, fn(xas) {
    let parts = string.split(xas.s3_object_id, "/")
    case list.length(parts) >= 4 {
      True -> {
        let prefix =
          list.take(parts, 2)
          |> string.join("/")
        let file_name =
          list.drop(parts, 3)
          |> string.join("/")
        Ok(#(prefix, file_name))
      }
      False -> Error(Nil)
    }
  })
  |> option.from_result
}
