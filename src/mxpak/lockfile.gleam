//// Reads and writes the mxpak widget lockfile.
////

import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import mxpak/error
import mxpak/toml_syntax
import mxpak/widget
import simplifile
import tom

/// A typed `LockEntry` value used by the lockfile capability.
pub type LockEntry {
  /// The `LockEntry` variant.
  LockEntry(
    version: String,
    hash: String,
    content_id: option.Option(Int),
    s3_id: option.Option(String),
    kind: widget.Kind,
  )
}

/// A typed `Lockfile` value used by the lockfile capability.
pub type Lockfile {
  /// The `Lockfile` variant.
  Lockfile(entries: dict.Dict(String, LockEntry))
}

/// Reads the project widget lockfile.
pub fn read(
  project_root project_root: String,
) -> Result(Lockfile, error.Error) {
  let path = project_root <> "/" <> lock_filename
  use content <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(_) { error.lockfile("mxpak.lock 읽기 실패") }),
  )
  use parsed <- result.try(
    tom.parse(content)
    |> result.map_error(fn(_) { error.lockfile("mxpak.lock 파싱 실패") }),
  )
  Ok(parse_lockfile(parsed))
}

/// Reports whether a project lockfile exists.
pub fn exists(project_root project_root: String) -> Result(Bool, error.Error) {
  let path = project_root <> "/" <> lock_filename
  simplifile.is_file(path)
  |> result.map_error(fn(reason) {
    error.lockfile(
      "mxpak.lock 확인 실패: " <> path <> ": " <> string.inspect(reason),
    )
  })
}

/// Writes the project widget lockfile.
pub fn write(
  project_root project_root: String,
  entries entries: dict.Dict(String, LockEntry),
) -> Result(Nil, error.Error) {
  let path = project_root <> "/" <> lock_filename
  let content = serialize_lockfile(entries)
  simplifile.write(path, content)
  |> result.map_error(fn(_) { error.lockfile("mxpak.lock 쓰기 실패") })
}

/// Returns the lock entry for a widget.
pub fn get_entry(
  lockfile lockfile: Lockfile,
  name name: String,
) -> Result(LockEntry, error.MissingValue) {
  dict.get(lockfile.entries, name)
  |> result.replace_error(error.MissingValue)
}

/// Removes the project widget lockfile.
pub fn remove(project_root project_root: String) -> Result(Nil, error.Error) {
  let path = project_root <> "/" <> lock_filename
  case simplifile.is_file(path) {
    Ok(True) ->
      simplifile.delete(path)
      |> result.map_error(fn(_) { error.lockfile("mxpak.lock 삭제 실패") })
    Ok(False) -> Ok(Nil)
    Error(reason) ->
      Error(error.lockfile(
        "mxpak.lock 확인 실패: " <> path <> ": " <> string.inspect(reason),
      ))
  }
}

const lock_filename = "mxpak.lock"

fn parse_lockfile(toml: dict.Dict(String, tom.Toml)) -> Lockfile {
  let entries = case tom.get_table(toml, ["widgets"]) {
    Ok(widgets_table) ->
      dict.fold(widgets_table, dict.new(), fn(acc, name, value) {
        case value {
          tom.Table(t) | tom.InlineTable(t) ->
            dict.insert(acc, name, parse_lock_entry(t))
          tom.Int(_)
          | tom.Float(_)
          | tom.Infinity(_)
          | tom.Nan(_)
          | tom.Bool(_)
          | tom.String(_)
          | tom.Date(_)
          | tom.Time(_)
          | tom.DateTime(..)
          | tom.Array(_)
          | tom.ArrayOfTables(_) -> acc
        }
      })
    Error(_) -> dict.new()
  }
  Lockfile(entries)
}

fn parse_lock_entry(table: dict.Dict(String, tom.Toml)) -> LockEntry {
  let version = tom.get_string(table, ["version"]) |> result.unwrap("")
  let hash = tom.get_string(table, ["hash"]) |> result.unwrap("")
  let content_id = tom.get_int(table, ["content_id"]) |> option.from_result
  let s3_id = tom.get_string(table, ["s3_id"]) |> option.from_result
  let kind = case tom.get_bool(table, ["classic"]) {
    Ok(True) -> widget.Classic
    Ok(False) | Error(_) -> widget.Pluggable
  }
  LockEntry(version, hash, content_id, s3_id, kind)
}

fn serialize_lockfile(entries: dict.Dict(String, LockEntry)) -> String {
  let header = "# mxpak.lock — 자동 생성 파일, 직접 수정하지 마세요\n\n"
  let sorted =
    dict.to_list(entries)
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
  let body =
    list.map(sorted, fn(pair) {
      let #(name, entry) = pair
      serialize_entry(name, entry)
    })
    |> string.join("\n")
  header <> body
}

fn serialize_entry(name: String, entry: LockEntry) -> String {
  let header = "[widgets." <> quote_key(name) <> "]\n"
  let lines = [
    "version = " <> toml_syntax.quote_basic_string(entry.version),
    "hash = " <> toml_syntax.quote_basic_string(entry.hash),
  ]
  let lines = case entry.content_id {
    option.Some(id) ->
      list.append(lines, ["content_id = " <> int.to_string(id)])
    option.None -> lines
  }
  let lines = case entry.s3_id {
    option.Some(s3) ->
      list.append(lines, [
        "s3_id = " <> toml_syntax.quote_basic_string(s3),
      ])
    option.None -> lines
  }
  let lines = case entry.kind {
    widget.Classic -> list.append(lines, ["classic = true"])
    widget.Pluggable -> lines
  }
  header <> string.join(lines, "\n") <> "\n"
}

fn quote_key(name: String) -> String {
  toml_syntax.quote_key(name)
}
