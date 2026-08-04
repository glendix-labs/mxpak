//// Provides the public content-addressable cache API for mxpak.
////

import mxpak/cache/integrity
import mxpak/cache/store
import mxpak/error

/// Computes a content hash for the supplied bytes.
pub fn hash(data data: BitArray) -> String {
  integrity.sha256(data)
}

/// Checks the supplied bytes against an expected content hash.
pub fn verify(
  data data: BitArray,
  expected_hash expected_hash: String,
) -> Bool {
  integrity.verify(data, expected_hash)
}

/// Reports whether the requested cache entry exists.
pub fn has(hash hash: String) -> Result(Bool, error.Error) {
  store.has(hash)
}

/// Stores an MPK and its extracted entries in the content-addressable cache.
pub fn put(
  data data: BitArray,
  entries entries: List(#(String, BitArray)),
) -> Result(#(String, String), error.Error) {
  store.put(data, entries)
}

/// Restores cached package entries into a project directory.
pub fn restore(
  hash hash: String,
  target_dir target_dir: String,
) -> Result(Nil, error.Error) {
  store.link_to_project(hash, target_dir)
}

/// Restores the original MPK from cache.
pub fn restore_mpk(
  hash hash: String,
  target_path target_path: String,
) -> Result(Nil, error.Error) {
  store.restore_mpk(hash, target_path)
}

/// Returns the cache path for a content hash.
pub fn path(hash hash: String) -> String {
  store.cache_path(hash)
}

/// Stores one file in the content-addressable cache.
pub fn put_file(
  data data: BitArray,
  filename filename: String,
) -> Result(#(String, String), error.Error) {
  store.put_file(data, filename)
}

/// Restores one cached file to the requested path.
pub fn restore_file(
  hash hash: String,
  filename filename: String,
  target_path target_path: String,
) -> Result(Nil, error.Error) {
  store.restore_file(hash, filename, target_path)
}

/// Removes all cached package data.
pub fn clean() -> Result(Nil, error.Error) {
  store.clean()
}
