//// Provides zip operations for mxpak.
////

import gleam/list
import gleam/result
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
  unzip_to_memory(zip_binary)
  |> result.map(fn(raw_entries) {
    list.map(raw_entries, fn(entry) {
      ZipEntry(name: entry.0, content: entry.1)
    })
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

// -- Erlang FFI --
@external(erlang, "mxpak_zip_ffi", "unzip_to_memory")
fn unzip_to_memory(
  zip_binary: BitArray,
) -> Result(List(#(String, BitArray)), error.Error)
