//// Provides output operations for mxpak.
////

import gleam/io
import gleam/json

/// Writes a user-facing log message.
pub fn log(message message: String) -> Nil {
  io.println_error(message)
}

/// Writes a successful JSON command result.
pub fn result_ok(widgets widgets: json.Json) -> Nil {
  let payload = json.object([#("ok", json.bool(True)), #("widgets", widgets)])
  io.println(result_marker)
  io.println(json.to_string(payload))
}

/// Writes a failed JSON command result.
pub fn result_error(message message: String) -> Nil {
  let payload =
    json.object([
      #("ok", json.bool(False)),
      #("error", json.string(message)),
    ])
  io.println(result_marker)
  io.println(json.to_string(payload))
}

const result_marker = "---MXP_RESULT---"
