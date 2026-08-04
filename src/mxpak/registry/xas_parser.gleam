//// Provides xas parser operations for mxpak.
////

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import mxpak/error

/// A typed `XasVersion` value used by the xas parser capability.
pub type XasVersion {
  /// The `XasVersion` variant.
  XasVersion(
    s3_object_id: String,
    react_ready: Bool,
    publish_date: String,
    version_number: String,
  )
}

/// Parses the xas body.
pub fn parse_xas_body(body body: String) -> List(XasVersion) {
  case json.parse(body, decode_xas_response()) {
    Ok(versions) -> versions
    Error(_) -> []
  }
}

/// Encodes the version.
pub fn encode_version(v v: XasVersion) -> json.Json {
  json.object([
    #("s3ObjectId", json.string(v.s3_object_id)),
    #("reactReady", json.bool(v.react_ready)),
    #("publishDate", json.string(v.publish_date)),
    #("versionNumber", json.string(v.version_number)),
  ])
}

fn decode_xas_response() -> decode.Decoder(List(XasVersion)) {
  use objects <- decode.field("objects", decode.list(decode_maybe_version()))
  decode.success(list.filter_map(objects, fn(x) { x }))
}

fn decode_maybe_version() -> decode.Decoder(
  Result(XasVersion, error.MissingValue),
) {
  use object_type <- decode.field("objectType", decode.string)
  case object_type {
    "AppStore.Version" -> {
      use attrs_opt <- decode.optional_field(
        "attributes",
        option.None,
        decode.optional(decode.dynamic),
      )
      case attrs_opt {
        option.None -> decode.success(Error(error.MissingValue))
        option.Some(attrs) -> extract_version(attrs)
      }
    }
    _ -> decode.success(Error(error.MissingValue))
  }
}

fn extract_version(
  attrs: decode.Dynamic,
) -> decode.Decoder(Result(XasVersion, error.MissingValue)) {
  case decode.run(attrs, decode.at(["S3ObjectId", "value"], decode.string)) {
    Error(_) -> decode.success(Error(error.MissingValue))
    Ok(s3_id) -> {
      let react =
        decode.run(
          attrs,
          decode.at(["IsReactClientReady", "value"], decode.bool),
        )
        |> result.unwrap(False)
      let date =
        decode.run(attrs, decode.at(["PublishDate", "value"], decode.string))
        |> result.unwrap("")
      let ver =
        decode.run(
          attrs,
          decode.at(["DisplayVersionNumber", "value"], decode.string),
        )
        |> result.unwrap("")
      decode.success(
        Ok(XasVersion(
          s3_object_id: s3_id,
          react_ready: react,
          publish_date: date,
          version_number: ver,
        )),
      )
    }
  }
}
