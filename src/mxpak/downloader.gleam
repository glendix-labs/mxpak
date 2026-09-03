//// Downloads, extracts, and restores Mendix widget packages.
////

import gleam/bit_array
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import mxpak/cache
import mxpak/cache/integrity
import mxpak/config/toml_writer
import mxpak/error
import mxpak/mpk/xml
import mxpak/mpk/zip
import mxpak/widget
import simplifile

/// A typed `DownloadResult` value used by the downloader capability.
pub type DownloadResult {
  /// The `DownloadResult` variant.
  DownloadResult(
    name: String,
    version: String,
    content_id: option.Option(Int),
    s3_id: String,
    hash: String,
    kind: widget.Kind,
  )
}

/// Downloads a widget package and writes its extracted assets.
pub fn download_and_extract(
  url url: String,
  name name: String,
  version version: String,
  content_id content_id: option.Option(Int),
  project_root project_root: String,
) -> Result(DownloadResult, error.Error) {
  use _ <- result.try(widget.validate_name(name))
  let cache_dir = project_root <> "/build/widgets/" <> name
  use zip_data <- result.try(download_binary(url))
  let hash = integrity.sha256(zip_data)
  use cached <- result.try(cache.has(hash))
  case cached {
    True -> {
      io.println_error(name <> " v" <> version <> " — 캐시 히트")
      use _ <- result.try(cache.restore(hash, cache_dir))
      use has_mjs <- result.try(has_mjs_in_dir(cache_dir))
      let kind = case has_mjs {
        True -> widget.Pluggable
        False -> widget.Classic
      }
      Ok(DownloadResult(name, version, content_id, url, hash, kind))
    }
    False -> {
      use entries <- result.try(
        zip.extract(zip_data)
        |> result.map_error(fn(e) {
          error.download(name <> " — 추출 실패: " <> error.message(e))
        }),
      )
      let has_mjs =
        list.any(entries, fn(e) { string.ends_with(e.name, ".mjs") })
      let kind = case has_mjs {
        True -> widget.Pluggable
        False -> widget.Classic
      }
      use save_entries <- result.try(build_save_entries(entries, kind))
      use _ <- result.try(cache.put(zip_data, save_entries))
      use _ <- result.try(write_to_project(save_entries, cache_dir))
      use _ <- result.try(toml_writer.write_meta_toml(
        cache_dir <> "/meta.toml",
        version,
        content_id,
        kind,
      ))
      io.println_error(
        name <> " v" <> version <> " — 다운로드 완료 [" <> short_hash(hash) <> "]",
      )
      Ok(DownloadResult(name, version, content_id, url, hash, kind))
    }
  }
}

/// Downloads a widget package as an MPK file.
pub fn download_mpk(
  url url: String,
  name name: String,
  version version: String,
  content_id content_id: option.Option(Int),
  target_path target_path: String,
) -> Result(DownloadResult, error.Error) {
  use _ <- result.try(widget.validate_name(name))
  use zip_data <- result.try(download_binary(url))
  let hash = integrity.sha256(zip_data)
  use cached <- result.try(cache.has(hash))
  case cached {
    True -> {
      io.println_error(name <> " v" <> version <> " — 캐시 히트")
      use _ <- result.try(cache.restore_mpk(hash, target_path))
      use kind <- result.try(detect_widget_kind_from_cache(hash))
      Ok(DownloadResult(name, version, content_id, url, hash, kind))
    }
    False -> {
      use entries <- result.try(
        zip.extract(zip_data)
        |> result.map_error(fn(e) {
          error.download(name <> " — 추출 실패: " <> error.message(e))
        }),
      )
      let has_mjs =
        list.any(entries, fn(e) { string.ends_with(e.name, ".mjs") })
      let kind = case has_mjs {
        True -> widget.Pluggable
        False -> widget.Classic
      }
      use save_entries <- result.try(build_save_entries(entries, kind))
      use _ <- result.try(cache.put(zip_data, save_entries))
      use _ <- result.try(cache.restore_mpk(hash, target_path))
      io.println_error(
        name <> " v" <> version <> " — 다운로드 완료 [" <> short_hash(hash) <> "]",
      )
      Ok(DownloadResult(name, version, content_id, url, hash, kind))
    }
  }
}

/// Restores the from cache.
pub fn restore_from_cache(
  hash hash: String,
  name name: String,
  version version: String,
  content_id content_id: option.Option(Int),
  project_root project_root: String,
) -> Result(DownloadResult, error.Error) {
  use _ <- result.try(widget.validate_name(name))
  let cache_dir = project_root <> "/build/widgets/" <> name
  use _ <- result.try(cache.restore(hash, cache_dir))
  use has_mjs <- result.try(has_mjs_in_dir(cache_dir))
  let kind = case has_mjs {
    True -> widget.Pluggable
    False -> widget.Classic
  }
  Ok(DownloadResult(name, version, content_id, "", hash, kind))
}

fn detect_widget_kind_from_cache(
  hash: String,
) -> Result(widget.Kind, error.Error) {
  let dir = cache.path(hash)
  use has_mjs <- result.try(has_mjs_in_dir(dir))
  Ok(case has_mjs {
    True -> widget.Pluggable
    False -> widget.Classic
  })
}

fn download_binary(url: String) -> Result(BitArray, error.Error) {
  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) { error.download("잘못된 URL: " <> url) }),
  )
  let config =
    httpc.configure()
    |> httpc.follow_redirects(True)
    |> httpc.timeout(60_000)
  let req = request.map(req, bit_array.from_string)
  httpc.dispatch_bits(config, req)
  |> result.map(fn(resp) { resp.body })
  |> result.map_error(fn(_) { error.download("다운로드 실패") })
}

/// Builds the save entries.
fn build_save_entries(
  entries: List(zip.ZipEntry),
  kind: widget.Kind,
) -> Result(List(#(String, BitArray)), error.Error) {
  use widget_xml_paths <- result.try(
    case list.find(entries, fn(e) { basename(e.name) == "package.xml" }) {
      Ok(pkg_entry) ->
        case bit_array.to_string(pkg_entry.content) {
          Ok(xml_string) ->
            xml.extract_widget_file_paths(xml_string)
            |> result.map_error(fn(reason) {
              error.download(
                "package.xml widget paths could not be parsed: "
                <> string.inspect(reason),
              )
            })
          Error(_) -> Error(error.download("package.xml was not valid UTF-8"))
        }
      Error(_) -> Ok([])
    },
  )
  list.filter_map(entries, fn(entry) {
    let name = entry.name
    let fname = basename(name)
    let content = entry.content
    // package.xml
    case fname == "package.xml" {
      True -> Ok(#(fname, content))
      False ->
        case list.contains(widget_xml_paths, name) {
          True -> Ok(#(fname, content))
          False ->
            case string.ends_with(name, ".mjs") {
              True -> Ok(#(fname, content))
              False ->
                case
                  string.ends_with(name, ".css")
                  && !string.contains(name, "editorPreview")
                {
                  True -> Ok(#(fname, content))
                  False ->
                    case
                      widget.is_classic(kind)
                      && !string.ends_with(name, "/")
                      && {
                        string.ends_with(name, ".js")
                        || string.ends_with(name, ".html")
                      }
                    {
                      True -> Ok(#(name, content))
                      False -> Error(Nil)
                    }
                }
            }
        }
    }
  })
  |> Ok
}

fn write_to_project(
  entries: List(#(String, BitArray)),
  cache_dir: String,
) -> Result(Nil, error.Error) {
  use _ <- result.try(create_dir(cache_dir))
  list.try_each(entries, fn(entry) {
    let #(name, content) = entry
    let out_path = cache_dir <> "/" <> name
    let dir = dirname(out_path)
    use _ <- result.try(create_dir(dir))
    write_file(out_path, content)
  })
}

fn create_dir(path: String) -> Result(Nil, error.Error) {
  case simplifile.create_directory_all(path) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(error.download("디렉토리 생성 실패: " <> path))
  }
}

fn write_file(path: String, content: BitArray) -> Result(Nil, error.Error) {
  simplifile.write_bits(path, content)
  |> result.map_error(fn(_) { error.download("파일 쓰기 실패: " <> path) })
}

fn has_mjs_in_dir(dir: String) -> Result(Bool, error.Error) {
  simplifile.read_directory(dir)
  |> result.map(fn(files) {
    list.any(files, fn(file) { string.ends_with(file, ".mjs") })
  })
  |> result.map_error(fn(reason) {
    error.download(
      "위젯 캐시 디렉터리 읽기 실패: " <> dir <> ": " <> string.inspect(reason),
    )
  })
}

fn basename(path: String) -> String {
  case string.split(path, "/") |> list.last {
    Ok(name) -> name
    Error(_) -> path
  }
}

fn dirname(path: String) -> String {
  let parts = string.split(path, "/")
  case list.length(parts) > 1 {
    True ->
      list.take(parts, list.length(parts) - 1)
      |> string.join("/")
    False -> "."
  }
}

fn short_hash(hash: String) -> String {
  string.slice(hash, 0, 8)
}
