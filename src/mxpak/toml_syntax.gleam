//// Provides TOML syntax encoding shared by generated TOML files.

import gleam/int
import gleam/list
import gleam/string

/// Encodes a value as a quoted TOML basic string with escapes.
pub fn quote_basic_string(value value: String) -> String {
  "\"" <> escape_basic_string(value) <> "\""
}

/// Encodes a TOML key as a bare key when legal and a quoted key otherwise.
pub fn quote_key(name name: String) -> String {
  case is_bare_key(name) {
    True -> name
    False -> quote_basic_string(name)
  }
}

fn is_bare_key(name: String) -> Bool {
  name != ""
  && {
    name
    |> string.to_utf_codepoints
    |> list.all(fn(codepoint) {
      let code = string.utf_codepoint_to_int(codepoint)
      { code >= 0x30 && code <= 0x39 }
      || { code >= 0x41 && code <= 0x5A }
      || { code >= 0x61 && code <= 0x7A }
      || code == 0x2D
      || code == 0x5F
    })
  }
}

fn escape_basic_string(value: String) -> String {
  value
  |> string.to_utf_codepoints
  |> list.map(escape_codepoint)
  |> string.concat
}

fn escape_codepoint(codepoint: UtfCodepoint) -> String {
  let code = string.utf_codepoint_to_int(codepoint)
  case code {
    0x08 -> "\\b"
    0x09 -> "\\t"
    0x0A -> "\\n"
    0x0C -> "\\f"
    0x0D -> "\\r"
    0x22 -> "\\\""
    0x5C -> "\\\\"
    escaped if escaped < 0x20 || escaped == 0x7F ->
      "\\u" <> string.pad_start(int.to_base16(escaped), 4, "0")
    _ -> string.from_utf_codepoints([codepoint])
  }
}
