//// Models the runtime kind of a Mendix widget package.
////

import gleam/string
import mxpak/error

/// Represents whether a widget uses the classic or pluggable runtime.
pub type Kind {
  /// A modern pluggable widget containing JavaScript modules.
  Pluggable
  /// A classic widget containing legacy JavaScript or HTML assets.
  Classic
}

/// Reports whether a widget uses the classic runtime.
pub fn is_classic(kind kind: Kind) -> Bool {
  case kind {
    Classic -> True
    Pluggable -> False
  }
}

/// Validates a configured widget name before it is used in a file path.
///
/// Widget names originate in project TOML files, so they are untrusted path
/// segments. Dotted names remain valid because they are legal TOML section
/// names and safe single path segments. Quotes are rejected because the
/// configured TOML parser cannot round-trip quoted keys that contain escaped
/// quotes, in addition to the path-safety rules above.
pub fn validate_name(name name: String) -> Result(Nil, error.Error) {
  case name {
    "" ->
      Error(error.configuration(
        "Widget name must not be empty when it is used in a file path",
      ))
    "." | ".." ->
      Error(error.configuration(
        "Widget name must not be a relative directory reference: " <> name,
      ))
    _ ->
      case
        string.contains(name, "/")
        || string.contains(name, "\\")
        || string.contains(name, "\"")
        || string.contains(name, "\u{0000}")
      {
        True ->
          Error(error.configuration(
            "Widget name must not contain path separators, quotes, or NUL: "
            <> name,
          ))
        False -> Ok(Nil)
      }
  }
}
