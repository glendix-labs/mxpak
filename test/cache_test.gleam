//// Tests cache behavior for mxpak.
////

import gleam/string
import gleeunit/should
import mxpak/cache
import mxpak/cache/integrity
import mxpak/cache/store
import simplifile

/// Verifies sha256 deterministic behavior.
pub fn sha256_deterministic_test() -> Nil {
  let hash1 = integrity.sha256(<<"hello":utf8>>)
  let hash2 = integrity.sha256(<<"hello":utf8>>)
  { hash1 == hash2 }
  |> should.be_true
  Nil
}

/// Verifies sha256 different inputs behavior.
pub fn sha256_different_inputs_test() -> Nil {
  let hash1 = integrity.sha256(<<"hello":utf8>>)
  let hash2 = integrity.sha256(<<"world":utf8>>)
  { hash1 != hash2 }
  |> should.be_true
  Nil
}

/// Verifies sha256 known value behavior.
pub fn sha256_known_value_test() -> Nil {
  // SHA-256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
  let hash = integrity.sha256(<<"hello":utf8>>)
  { hash == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" }
  |> should.be_true
  Nil
}

/// Verifies sha256 hex length behavior.
pub fn sha256_hex_length_test() -> Nil {
  let hash = integrity.sha256(<<"test":utf8>>)
  { string.length(hash) == 64 }
  |> should.be_true
  Nil
}

/// Verifies verify success behavior.
pub fn verify_success_test() -> Nil {
  let data = <<"verify me":utf8>>
  let hash = integrity.sha256(data)
  integrity.verify(data, hash)
  |> should.be_true
  Nil
}

/// Verifies verify failure behavior.
pub fn verify_failure_test() -> Nil {
  integrity.verify(<<"data":utf8>>, "wrong_hash")
  |> should.be_false
  Nil
}

/// Verifies store put and has behavior.
pub fn store_put_and_has_test() -> Nil {
  let data = <<"test zip data":utf8>>
  let entries = [#("file.txt", <<"content":utf8>>)]
  let stored =
    store.put(data, entries)
    |> should.be_ok
  let hash = stored.1
  store.has(hash)
  |> should.be_ok
  |> should.be_true
  simplifile.delete(store.cache_path(hash))
  |> should.be_ok
  Nil
}

/// Verifies store has missing behavior.
pub fn store_has_missing_test() -> Nil {
  store.has("nonexistent_hash_123")
  |> should.be_ok
  |> should.be_false
  Nil
}

/// Verifies package stores write a manifest and restore only payload entries.
pub fn store_put_completes_packages_test() -> Nil {
  let data = <<"package bytes":utf8>>
  let entries = [
    #("package.xml", <<"<package/>":utf8>>),
    #("com/Widget.mjs", <<"export default 1":utf8>>),
  ]
  let stored =
    store.put(data, entries)
    |> should.be_ok
  let hash = stored.1
  store.has_package(hash)
  |> should.be_ok
  |> should.be_true
  let target = "build/test_tmp/restore_complete"
  store.link_to_project(hash, target)
  |> should.be_ok
  simplifile.is_file(target <> "/manifest.mxpak")
  |> should.be_ok
  |> should.be_false
  simplifile.is_file(target <> "/com/Widget.mjs")
  |> should.be_ok
  |> should.be_true
  simplifile.delete(target)
  |> should.be_ok
  simplifile.delete(store.cache_path(hash))
  |> should.be_ok
  Nil
}

/// Verifies incomplete package directories are rebuilt instead of trusted.
pub fn store_put_rebuilds_incomplete_packages_test() -> Nil {
  let data = <<"incomplete package":utf8>>
  let hash = integrity.sha256(data)
  let dir = store.cache_path(hash)
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write_bits(dir <> "/partial.txt", <<"partial":utf8>>)
  |> should.be_ok
  store.has_package(hash)
  |> should.be_ok
  |> should.be_false
  store.put(data, [#("complete.txt", <<"complete":utf8>>)])
  |> should.be_ok
  store.has_package(hash)
  |> should.be_ok
  |> should.be_true
  simplifile.is_file(dir <> "/partial.txt")
  |> should.be_ok
  |> should.be_false
  simplifile.is_file(dir <> "/complete.txt")
  |> should.be_ok
  |> should.be_true
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies cache roundtrip behavior.
pub fn cache_roundtrip_test() -> Nil {
  let data = <<"roundtrip test":utf8>>
  let entries = [#("test.xml", <<"<widget/>":utf8>>)]
  let hash = cache.hash(data)
  cache.verify(data, hash)
  |> should.be_true
  let stored =
    cache.put(data, entries)
    |> should.be_ok
  let stored_hash = stored.1
  { hash == stored_hash }
  |> should.be_true
  cache.has(hash)
  |> should.be_ok
  |> should.be_true
  let target = "build/test_tmp/cache_restore"
  simplifile.create_directory_all(target)
  |> should.be_ok
  cache.restore(hash, target)
  |> should.be_ok
  let content =
    simplifile.read_bits(target <> "/test.xml")
    |> should.be_ok
  { content == <<"<widget/>":utf8>> }
  |> should.be_true
  simplifile.delete(store.cache_path(hash))
  |> should.be_ok
  simplifile.delete(target)
  |> should.be_ok
  Nil
}
