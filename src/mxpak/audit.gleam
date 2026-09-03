//// Verifies cached package contents against lockfile hashes.
////

import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import mxpak/cache/integrity
import mxpak/cache/store
import mxpak/error
import mxpak/lockfile
import simplifile

/// The verification outcome for one locked widget.
pub type AuditStatus {
  /// The cached MPK content matches the pinned hash.
  Verified(version: String)
  /// The cached MPK content differs from the pinned hash.
  HashMismatch(version: String, expected: String, actual: String)
  /// No cache entry exists for the pinned hash.
  CacheMissing(version: String)
  /// The cache entry exists but its MPK could not be read.
  CacheUnreadable(version: String, reason: String)
  /// The lock entry has no pinned hash to verify.
  HashUnavailable(version: String)
}

/// One widget audit result.
pub type EntryAudit {
  EntryAudit(name: String, status: AuditStatus)
}

/// Audits every lock entry against the global content-addressable cache.
pub fn verify(
  project_root project_root: String,
) -> Result(List(EntryAudit), error.Error) {
  use lock <- result.try(lockfile.read(project_root))
  Ok(verify_entries(lock.entries, store.cache_root()))
}

/// Audits lock entries against the supplied cache root.
pub fn verify_entries(
  entries entries: dict.Dict(String, lockfile.LockEntry),
  cache_root cache_root: String,
) -> List(EntryAudit) {
  entries
  |> dict.to_list
  |> list.sort(fn(left, right) { string.compare(left.0, right.0) })
  |> list.map(fn(pair) {
    let #(name, entry) = pair
    EntryAudit(name: name, status: audit_entry(entry, cache_root))
  })
}

fn audit_entry(
  entry entry: lockfile.LockEntry,
  cache_root cache_root: String,
) -> AuditStatus {
  case entry.hash {
    "" -> HashUnavailable(entry.version)
    hash -> {
      let mpk_path = cache_root <> "/" <> hash <> "/original.mpk"
      case simplifile.read_bits(mpk_path) {
        Error(simplifile.Enoent) -> CacheMissing(entry.version)
        Error(reason) -> CacheUnreadable(entry.version, string.inspect(reason))
        Ok(data) ->
          case integrity.sha256(data) == hash {
            True -> Verified(entry.version)
            False ->
              HashMismatch(
                version: entry.version,
                expected: hash,
                actual: integrity.sha256(data),
              )
          }
      }
    }
  }
}
