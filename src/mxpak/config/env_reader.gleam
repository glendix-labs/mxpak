//// Provides env reader operations for mxpak.
////

import envoy
import gleam/list
import gleam/option
import gleam/string
import mxpak/error
import simplifile

/// Reads a value from the project environment file.
pub fn get(
  key key: String,
  project_root project_root: String,
) -> Result(option.Option(String), error.Error) {
  case envoy.get(key) {
    Ok(val) -> Ok(option.Some(val))
    Error(_) -> read_from_dotenv(key, project_root)
  }
}

/// Reads the from dotenv.
fn read_from_dotenv(
  key: String,
  project_root: String,
) -> Result(option.Option(String), error.Error) {
  let path = project_root <> "/.env"
  case simplifile.read(path) {
    Error(simplifile.Enoent) -> Ok(option.None)
    Error(reason) ->
      Error(error.configuration(
        "환경 파일 읽기 실패: " <> path <> ": " <> string.inspect(reason),
      ))
    Ok(content) ->
      string.split(content, "\n")
      |> list.find_map(fn(line) {
        let trimmed = string.trim(line)
        case trimmed == "" || string.starts_with(trimmed, "#") {
          True -> Error(Nil)
          False ->
            case string.split_once(trimmed, "=") {
              Ok(#(k, v)) ->
                case string.trim(k) == key {
                  True ->
                    Ok(
                      string.trim(v)
                      |> strip_quotes,
                    )
                  False -> Error(Nil)
                }
              _ -> Error(Nil)
            }
        }
      })
      |> option.from_result
      |> Ok
  }
}

fn strip_quotes(value value: String) -> String {
  case
    string.length(value) >= 2
    && string.starts_with(value, "\"")
    && string.ends_with(value, "\"")
  {
    True ->
      value
      |> string.drop_start(1)
      |> string.drop_end(1)
    False ->
      case
        string.length(value) >= 2
        && string.starts_with(value, "'")
        && string.ends_with(value, "'")
      {
        True ->
          value
          |> string.drop_start(1)
          |> string.drop_end(1)
        False -> value
      }
  }
}
