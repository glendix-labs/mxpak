//// Tests audit behavior for mxpak.
////

import gleam/dict
import gleam/list
import gleam/option
import gleeunit
import gleeunit/should
import mxpak/audit
import mxpak/cache/integrity
import mxpak/lockfile
import mxpak/widget
import simplifile

/// Runs this module's test suite.
pub fn main() -> Nil {
  gleeunit.main()
}

/// Verifies matching cache content reports as verified.
pub fn audit_verified_content_test() -> Nil {
  let root = "build/test_tmp/audit_ok"
  let hash = integrity.sha256(<<"package bytes":utf8>>)
  write_cache_entry(root, hash, <<"package bytes":utf8>>)
  let entries =
    dict.from_list([
      #(
        "DataGrid",
        lockfile.LockEntry(
          "1.0.0",
          hash,
          option.None,
          option.None,
          widget.Classic,
        ),
      ),
    ])
  audit.verify_entries(entries, root)
  |> list.first
  |> should.equal(
    Ok(audit.EntryAudit(
      name: "DataGrid",
      status: audit.Verified(version: "1.0.0"),
    )),
  )
  simplifile.delete(root)
  |> should.be_ok
  Nil
}

/// Verifies tampered cache content reports a hash mismatch.
pub fn audit_tampered_content_test() -> Nil {
  let root = "build/test_tmp/audit_tampered"
  let expected = integrity.sha256(<<"expected bytes":utf8>>)
  write_cache_entry(root, expected, <<"tampered bytes":utf8>>)
  let entries =
    dict.from_list([
      #(
        "DataGrid",
        lockfile.LockEntry(
          "1.0.0",
          expected,
          option.None,
          option.None,
          widget.Classic,
        ),
      ),
    ])
  audit.verify_entries(entries, root)
  |> list.first
  |> should.equal(
    Ok(audit.EntryAudit(
      name: "DataGrid",
      status: audit.HashMismatch(
        version: "1.0.0",
        expected: expected,
        actual: integrity.sha256(<<"tampered bytes":utf8>>),
      ),
    )),
  )
  simplifile.delete(root)
  |> should.be_ok
  Nil
}

/// Verifies missing cache content and missing hashes report distinctly.
pub fn audit_missing_states_test() -> Nil {
  let root = "build/test_tmp/audit_missing"
  let hash = integrity.sha256(<<"unused":utf8>>)
  let entries =
    dict.from_list([
      #(
        "Missing",
        lockfile.LockEntry(
          "1.0.0",
          hash,
          option.None,
          option.None,
          widget.Classic,
        ),
      ),
      #(
        "NoHash",
        lockfile.LockEntry(
          "1.0.0",
          "",
          option.None,
          option.None,
          widget.Classic,
        ),
      ),
    ])
  let results = audit.verify_entries(entries, root)
  { list.length(results) == 2 }
  |> should.be_true
  results
  |> list.find(fn(entry) { entry.name == "Missing" })
  |> should.equal(
    Ok(audit.EntryAudit(
      name: "Missing",
      status: audit.CacheMissing(version: "1.0.0"),
    )),
  )
  results
  |> list.find(fn(entry) { entry.name == "NoHash" })
  |> should.equal(
    Ok(audit.EntryAudit(
      name: "NoHash",
      status: audit.HashUnavailable(version: "1.0.0"),
    )),
  )
  Nil
}

fn write_cache_entry(root: String, hash: String, content: BitArray) -> Nil {
  let dir = root <> "/" <> hash
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write_bits(dir <> "/original.mpk", content)
  |> should.be_ok
  Nil
}
