//// Tests mxpak workspace filesystem boundary contracts.
////

import gleam/string
import gleeunit/should
import mxpak/cache/store
import mxpak/error
import mxpak/workspace/file_boundary

/// Verifies ZIP and filesystem errors retain their typed package representation.
pub fn filesystem_metadata_error_contract_test() -> Nil {
  file_boundary.inspect("build/test_tmp/does-not-exist")
  |> should.be_error
  |> error.message
  |> string.contains("read file metadata failed")
  |> should.be_true
}

/// Verifies recursive listing failures retain their typed package representation.
pub fn recursive_listing_error_contract_test() -> Nil {
  file_boundary.list_recursively("build/test_tmp/does-not-exist", [])
  |> should.be_error
  |> error.message
  |> string.contains("list directory recursively failed")
  |> should.be_true
}

/// Verifies hard-link failures retain their typed package representation.
pub fn hard_link_error_contract_test() -> Nil {
  store.create_hard_link(
    "build/test_tmp/missing-source",
    "build/test_tmp/missing-target",
  )
  |> should.be_error
  |> error.message
  |> string.contains("create hard link failed")
  |> should.be_true
}
