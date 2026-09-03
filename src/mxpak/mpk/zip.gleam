//// Provides zip operations for mxpak.
////

import gleam/list
import gleam/result
import gleam/string
import mxpak/error

/// A typed `ZipEntry` value used by the zip capability.
pub type ZipEntry {
  /// The `ZipEntry` variant.
  ZipEntry(name: String, content: BitArray)
}

/// Extracts every entry from an MPK archive.
pub fn extract(
  zip_binary zip_binary: BitArray,
) -> Result(List(ZipEntry), error.Error) {
  use raw_entries <- result.try(unzip_to_memory(zip_binary))
  raw_entries
  |> list.try_map(fn(entry) {
    use _ <- result.try(validate_entry_name(entry.0))
    Ok(ZipEntry(name: entry.0, content: entry.1))
  })
}

/// Extracts one file from an MPK archive.
pub fn extract_file(
  zip_binary zip_binary: BitArray,
  file_name file_name: String,
) -> Result(BitArray, error.Error) {
  use entries <- result.try(extract(zip_binary))
  list.find(entries, fn(e) { e.name == file_name })
  |> result.replace_error(error.download("ZIP 엔트리를 찾을 수 없습니다: " <> file_name))
  |> result.map(fn(e) { e.content })
}

/// Lists the file names in an MPK archive.
pub fn list_entries(
  zip_binary zip_binary: BitArray,
) -> Result(List(String), error.Error) {
  use entries <- result.map(extract(zip_binary))
  list.map(entries, fn(e) { e.name })
}

/// Rejects archive paths that could escape an extraction root.
fn validate_entry_name(name name: String) -> Result(Nil, error.Error) {
  let segments = string.split(name, "/")
  case
    name == ""
    || string.starts_with(name, "/")
    || string.contains(name, "\\")
    || list.contains(segments, "..")
  {
    True -> Error(error.download("ZIP 엔트리 경로가 안전하지 않습니다: " <> name))
    False -> Ok(Nil)
  }
}

// -- Erlang FFI --
@external(erlang, "mxpak_zip_ffi", "unzip_to_memory")
fn unzip_to_memory(
  zip_binary: BitArray,
) -> Result(List(#(String, BitArray)), error.Error)
