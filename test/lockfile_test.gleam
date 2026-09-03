//// Tests lockfile behavior for mxpak.
////

import gleam/dict
import gleam/option
import gleam/string
import gleeunit/should
import mxpak/lockfile
import mxpak/widget
import simplifile

/// Verifies write and read behavior.
pub fn write_and_read_test() -> Nil {
  let dir = "build/test_tmp/lock1"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let entries =
    dict.new()
    |> dict.insert(
      "DataGrid",
      lockfile.LockEntry(
        "2.5.0",
        "abc123hash",
        option.Some(12_345),
        option.Some("w/id/2.5.0/DG.mpk"),
        widget.Pluggable,
      ),
    )
    |> dict.insert(
      "Charts",
      lockfile.LockEntry(
        "1.0.0",
        "def456hash",
        option.None,
        option.None,
        widget.Classic,
      ),
    )
  lockfile.write(dir, entries)
  |> should.be_ok
  let lock =
    lockfile.read(dir)
    |> should.be_ok
  let dg =
    lockfile.get_entry(lock, "DataGrid")
    |> should.be_ok
  { dg.version == "2.5.0" }
  |> should.be_true
  { dg.hash == "abc123hash" }
  |> should.be_true
  dg.content_id
  |> should.equal(option.Some(12_345))
  dg.s3_id
  |> should.equal(option.Some("w/id/2.5.0/DG.mpk"))
  dg.kind
  |> should.equal(widget.Pluggable)
  let ch =
    lockfile.get_entry(lock, "Charts")
    |> should.be_ok
  { ch.version == "1.0.0" }
  |> should.be_true
  ch.kind
  |> should.equal(widget.Classic)
  ch.content_id
  |> should.be_none
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies exists true behavior.
pub fn exists_true_test() -> Nil {
  let dir = "build/test_tmp/lock2"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(dir <> "/mxpak.lock", "# empty\n")
  |> should.be_ok
  lockfile.exists(dir)
  |> should.be_ok
  |> should.be_true
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies exists false behavior.
pub fn exists_false_test() -> Nil {
  lockfile.exists("build/test_tmp/no_lock")
  |> should.be_ok
  |> should.be_false
  Nil
}

/// Verifies read missing behavior.
pub fn read_missing_test() -> Nil {
  lockfile.read("build/test_tmp/no_lock")
  |> should.be_error
  Nil
}

/// Verifies remove behavior.
pub fn remove_test() -> Nil {
  let dir = "build/test_tmp/lock3"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(dir <> "/mxpak.lock", "# test\n")
  |> should.be_ok
  lockfile.remove(dir)
  |> should.be_ok
  lockfile.exists(dir)
  |> should.be_ok
  |> should.be_false
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies quoted key behavior.
pub fn quoted_key_test() -> Nil {
  let dir = "build/test_tmp/lock4"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let entries =
    dict.new()
    |> dict.insert(
      "Data Widgets",
      lockfile.LockEntry(
        "1.0.0",
        "hash",
        option.None,
        option.None,
        widget.Pluggable,
      ),
    )
  lockfile.write(dir, entries)
  |> should.be_ok
  let content =
    simplifile.read(dir <> "/mxpak.lock")
    |> should.be_ok
  {
    content
    |> string_contains("[widgets.\"Data Widgets\"]")
  }
  |> should.be_true
  let lock =
    lockfile.read(dir)
    |> should.be_ok
  let entry =
    lockfile.get_entry(lock, "Data Widgets")
    |> should.be_ok
  { entry.version == "1.0.0" }
  |> should.be_true
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies hostile names and versions round-trip through the lockfile.
pub fn hostile_values_round_trip_test() -> Nil {
  let dir = "build/test_tmp/lock5"
  let hostile_name = "Data Grid 1"
  let hostile_version = "1.0\"0\n"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let entries =
    dict.new()
    |> dict.insert(
      hostile_name,
      lockfile.LockEntry(
        hostile_version,
        "hash",
        option.None,
        option.Some("s3\"id"),
        widget.Pluggable,
      ),
    )
  lockfile.write(dir, entries)
  |> should.be_ok
  let lock = lockfile.read(dir) |> should.be_ok
  let entry = lockfile.get_entry(lock, hostile_name) |> should.be_ok
  entry.version
  |> should.equal(hostile_version)
  entry.s3_id
  |> should.equal(option.Some("s3\"id"))
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

fn string_contains(haystack: String, needle: String) -> Bool {
  string.contains(haystack, needle)
}
