//// Provides typed filesystem metadata and traversal at the mxpak Erlang boundary.
////

import gleam/result
import mxpak/error

/// Metadata required by workspace deduplication.
pub type FileMetadata {
  /// File size and inode identifier.
  FileMetadata(size_bytes: Int, inode: Int)
}

/// Reads filesystem metadata for one path.
@internal
pub fn inspect(path path: String) -> Result(FileMetadata, error.Error) {
  use metadata <- result.try(file_info(path))
  Ok(FileMetadata(size_bytes: metadata.0, inode: metadata.1))
}

/// Recursively lists files while excluding directories by name.
@internal
pub fn list_recursively(
  from directory: String,
  excluding excluded_directories: List(String),
) -> Result(List(String), error.Error) {
  list_dir_recursive(directory, excluded_directories)
}

// -- FFI --

@external(erlang, "mxpak_ffi", "file_info")
fn file_info(path: String) -> Result(#(Int, Int), error.Error)

@external(erlang, "mxpak_ffi", "list_dir_recursive")
fn list_dir_recursive(
  directory: String,
  excluded_directories: List(String),
) -> Result(List(String), error.Error)
