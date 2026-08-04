//// Provides toml writer operations for mxpak.
////

import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import mxpak/error
import mxpak/widget
import simplifile

/// Adds or updates one `[tools.mxpak.widgets.*]` entry.
pub fn write_widget(
  project_root project_root: String,
  name name: String,
  version version: String,
  content_id content_id: option.Option(Int),
  s3_id s3_id: option.Option(String),
) -> Result(Nil, error.Error) {
  let toml_path = project_root <> "/gleam.toml"
  use content <- result.try(
    simplifile.read(toml_path)
    |> result.map_error(fn(_) { error.configuration("gleam.toml 읽기 실패") }),
  )
  let section_header = "[tools.mxpak.widgets." <> quote_key(name) <> "]"
  let entries =
    [#("version", quote_string(version))]
    |> append_opt(content_id, fn(id) { #("id", int.to_string(id)) })
    |> append_opt(s3_id, fn(s) { #("s3_id", quote_string(s)) })
  let new_content = case string.contains(content, section_header) {
    True ->
      list.fold(entries, content, fn(acc, entry) {
        update_key_in_section(acc, section_header, entry.0, entry.1)
      })
    False -> {
      let section_lines =
        list.map(entries, fn(e) { e.0 <> " = " <> e.1 })
        |> string.join("\n")
      let insertion = "\n\n" <> section_header <> "\n" <> section_lines <> "\n"
      insert_after_mxpak_section(content, insertion)
    }
  }
  simplifile.write(toml_path, new_content)
  |> result.map_error(fn(_) { error.configuration("gleam.toml 쓰기 실패") })
}

/// Removes one `[tools.mxpak.widgets.*]` entry.
pub fn remove_widget(
  project_root project_root: String,
  name name: String,
) -> Result(Nil, error.Error) {
  let toml_path = project_root <> "/gleam.toml"
  use content <- result.try(
    simplifile.read(toml_path)
    |> result.map_error(fn(_) { error.configuration("gleam.toml 읽기 실패") }),
  )
  let section_header = "[tools.mxpak.widgets." <> quote_key(name) <> "]"
  let new_content = remove_section(content, section_header)
  simplifile.write(toml_path, new_content)
  |> result.map_error(fn(_) { error.configuration("gleam.toml 쓰기 실패") })
}

/// Writes metadata beside an extracted package.
pub fn write_meta_toml(
  path path: String,
  version version: String,
  id id: option.Option(Int),
  kind kind: widget.Kind,
) -> Result(Nil, error.Error) {
  let lines = ["version = " <> quote_string(version)]
  let lines = case id {
    option.Some(i) -> list.append(lines, ["id = " <> int.to_string(i)])
    option.None -> lines
  }
  let lines = case kind {
    widget.Classic -> list.append(lines, ["classic = true"])
    widget.Pluggable -> lines
  }
  simplifile.write(path, string.join(lines, "\n") <> "\n")
  |> result.map_error(fn(_) { error.configuration("meta.toml 쓰기 실패: " <> path) })
}

/// Quotes a TOML key when required.
pub fn quote_key(name name: String) -> String {
  case
    string.contains(name, " ")
    || string.contains(name, "-")
    || string.contains(name, ".")
  {
    True -> "\"" <> name <> "\""
    False -> name
  }
}

fn quote_string(value: String) -> String {
  "\"" <> value <> "\""
}

/// Updates the key in section.
fn update_key_in_section(
  content: String,
  section_header: String,
  key: String,
  value: String,
) -> String {
  let lines = string.split(content, "\n")
  let new_line = key <> " = " <> value
  let #(result_lines, _, found_key) =
    list.fold(lines, #([], False, False), fn(state, line) {
      let #(acc, in_section, key_found) = state
      let trimmed = string.trim(line)
      case in_section {
        False ->
          case trimmed == section_header {
            True -> #([line, ..acc], True, key_found)
            False -> #([line, ..acc], False, key_found)
          }
        True ->
          case string.starts_with(trimmed, "[") {
            True -> {
              case key_found {
                True -> #([line, ..acc], False, key_found)
                False -> #([line, new_line, ..acc], False, True)
              }
            }
            False ->
              case
                string.starts_with(trimmed, key <> " ")
                || string.starts_with(trimmed, key <> "=")
              {
                True -> #([new_line, ..acc], True, True)
                False -> #([line, ..acc], True, key_found)
              }
          }
      }
    })
  let final_lines = case found_key {
    True -> result_lines
    False -> [new_line, ..result_lines]
  }
  list.reverse(final_lines) |> string.join("\n")
}

/// Inserts configuration after the mxpak tool section.
fn insert_after_mxpak_section(content: String, block: String) -> String {
  let lines = string.split(content, "\n")
  let last_mxpak_index = find_last_mxpak_line(lines, 0, -1, False)
  case last_mxpak_index >= 0 {
    True -> {
      let #(before, after) = list_split_at(lines, last_mxpak_index + 1)
      string.join(before, "\n") <> block <> string.join(after, "\n")
    }
    False -> content <> block
  }
}

fn find_last_mxpak_line(
  lines: List(String),
  idx: Int,
  last: Int,
  in_mxpak: Bool,
) -> Int {
  case lines {
    [] -> last
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "[tools.mxpak") {
        True -> find_last_mxpak_line(rest, idx + 1, idx, True)
        False ->
          case in_mxpak && !string.starts_with(trimmed, "[") {
            True -> find_last_mxpak_line(rest, idx + 1, idx, True)
            False ->
              case in_mxpak {
                True -> find_last_mxpak_line(rest, idx + 1, last, False)
                False -> find_last_mxpak_line(rest, idx + 1, last, False)
              }
          }
      }
    }
  }
}

/// Removes the section.
fn remove_section(content: String, section_header: String) -> String {
  let lines = string.split(content, "\n")
  let #(result_lines, _) =
    list.fold(lines, #([], False), fn(state, line) {
      let #(acc, skipping) = state
      let trimmed = string.trim(line)
      case skipping {
        True ->
          case string.starts_with(trimmed, "[") {
            True -> #([line, ..acc], False)
            False -> #(acc, True)
          }
        False ->
          case trimmed == section_header {
            True -> #(acc, True)
            False -> #([line, ..acc], False)
          }
      }
    })
  list.reverse(result_lines) |> string.join("\n")
}

fn append_opt(
  entries: List(#(String, String)),
  opt: option.Option(a),
  to_entry: fn(a) -> #(String, String),
) -> List(#(String, String)) {
  case opt {
    option.Some(v) -> list.append(entries, [to_entry(v)])
    option.None -> entries
  }
}

fn list_split_at(items: List(a), at: Int) -> #(List(a), List(a)) {
  list_split_at_acc(items, at, [])
}

fn list_split_at_acc(
  items: List(a),
  at: Int,
  acc: List(a),
) -> #(List(a), List(a)) {
  case at <= 0 || items == [] {
    True -> #(list.reverse(acc), items)
    False ->
      case items {
        [] -> #(list.reverse(acc), [])
        [x, ..rest] -> list_split_at_acc(rest, at - 1, [x, ..acc])
      }
  }
}
