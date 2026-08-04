//// Provides xml operations for mxpak.
////

import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string

/// Represents a widget XML parsing failure.
pub type ParseError {
  /// A parser expression could not be compiled.
  ParserCouldNotBeCreated(name: String, reason: regexp.CompileError)
  /// The widget XML did not contain a widget name.
  WidgetNameNotFound
  /// A property element did not contain a key.
  PropertyKeyNotFound(attributes: String)
  /// A matched XML fragment did not expose the expected capture.
  CaptureWasMissing(name: String)
}

/// Represents a widget property discovered in widget XML.
pub type WidgetProperty {
  /// Stores the property key and whether the property is required.
  WidgetProperty(key: String, required: Bool)
}

/// Parses the widget name from widget XML.
pub fn parse_widget_name(xml xml: String) -> Result(String, ParseError) {
  use name_pattern <- result.try(compile_pattern(
    "widget name",
    "<name>([^<]+)</name>",
  ))
  case regexp.scan(name_pattern, xml) {
    [match, ..] ->
      case match.submatches {
        [option.Some(name), ..] -> Ok(name)
        _ -> Error(CaptureWasMissing(name: "widget name"))
      }
    [] -> Error(WidgetNameNotFound)
  }
}

/// Parses every widget file path from package XML.
pub fn extract_widget_file_paths(
  package_xml package_xml: String,
) -> Result(List(String), ParseError) {
  use path_pattern <- result.try(compile_pattern(
    "widget file path",
    "widgetFile\\s+path=\"([^\"]+)\"",
  ))
  regexp.scan(path_pattern, package_xml)
  |> list.try_map(fn(match) {
    case match.submatches {
      [option.Some(path), ..] -> Ok(path)
      _ -> Error(CaptureWasMissing(name: "widget file path"))
    }
  })
}

/// Parses every property declaration from widget XML.
pub fn parse_properties(
  widget_xml widget_xml: String,
) -> Result(List(WidgetProperty), ParseError) {
  use property_pattern <- result.try(compile_pattern(
    "widget property",
    "<property\\s+([^>]*?)\\s*(?:/>|>)",
  ))
  regexp.scan(property_pattern, widget_xml)
  |> list.try_map(fn(match) {
    case match.submatches {
      [option.Some(attrs), ..] -> parse_property_attrs(attrs)
      _ -> Error(CaptureWasMissing(name: "widget property"))
    }
  })
}

/// Converts a widget name into a safe Gleam identifier.
pub fn to_safe_identifier(name name: String) -> String {
  string.to_graphemes(name)
  |> list.filter(fn(ch) { is_alnum_or_underscore(ch) })
  |> string.concat
}

/// Converts a widget name into a module file name.
pub fn to_module_file_name(name name: String) -> String {
  name
  |> string.replace(" ", "_")
  |> camel_to_snake
  |> string.lowercase
}

/// camelCase → snake_case
pub fn to_snake_case(str str: String) -> String {
  camel_to_snake(str) |> string.lowercase
}

/// Converts a property name into a Gleam variable name.
pub fn to_gleam_var(key key: String) -> String {
  let snake = to_snake_case(key)
  case is_gleam_keyword(snake) {
    True -> snake <> "_"
    False -> snake
  }
}

const gleam_keywords = [
  "as", "assert", "auto", "case", "const", "delegate", "derive", "echo", "else",
  "fn", "if", "implement", "import", "let", "macro", "opaque", "panic", "pub",
  "return", "test", "todo", "type", "use",
]

fn parse_property_attrs(attrs: String) -> Result(WidgetProperty, ParseError) {
  use key_pattern <- result.try(compile_pattern(
    "property key",
    "key=\"([^\"]+)\"",
  ))
  use required_pattern <- result.try(compile_pattern(
    "required property flag",
    "required=\"([^\"]+)\"",
  ))
  case regexp.scan(key_pattern, attrs) {
    [key_match, ..] ->
      case key_match.submatches {
        [option.Some(key), ..] -> {
          let required = case regexp.scan(required_pattern, attrs) {
            [req_match, ..] ->
              case req_match.submatches {
                [option.Some("true"), ..] -> True
                _ -> False
              }
            [] -> False
          }
          Ok(WidgetProperty(key: key, required: required))
        }
        _ -> Error(CaptureWasMissing(name: "property key"))
      }
    [] -> Error(PropertyKeyNotFound(attributes: attrs))
  }
}

fn camel_to_snake(str: String) -> String {
  camel_graphemes_to_snake(string.to_graphemes(str), option.None)
  |> string.concat
}

fn camel_graphemes_to_snake(
  graphemes: List(String),
  previous: option.Option(String),
) -> List(String) {
  case graphemes {
    [] -> []
    [current, ..rest] -> {
      let next = list.first(rest) |> option.from_result
      let needs_separator = case previous {
        option.None -> False
        option.Some(previous_grapheme) ->
          is_uppercase(current)
          && {
            is_lowercase_or_digit(previous_grapheme)
            || {
              is_uppercase(previous_grapheme)
              && is_lowercase(option.unwrap(next, ""))
            }
          }
      }
      let separator = case needs_separator {
        True -> "_"
        False -> ""
      }
      [
        separator <> string.lowercase(current),
        ..camel_graphemes_to_snake(rest, option.Some(current))
      ]
    }
  }
}

fn is_alnum_or_underscore(ch: String) -> Bool {
  string.contains(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$",
    ch,
  )
}

fn is_uppercase(grapheme: String) -> Bool {
  grapheme != string.lowercase(grapheme)
}

fn is_lowercase(grapheme: String) -> Bool {
  grapheme != string.uppercase(grapheme)
}

fn is_lowercase_or_digit(grapheme: String) -> Bool {
  is_lowercase(grapheme) || string.contains("0123456789", grapheme)
}

fn compile_pattern(
  name: String,
  source: String,
) -> Result(regexp.Regexp, ParseError) {
  regexp.from_string(source)
  |> result.map_error(fn(reason) {
    ParserCouldNotBeCreated(name: name, reason: reason)
  })
}

fn is_gleam_keyword(word: String) -> Bool {
  list.contains(gleam_keywords, word)
}
