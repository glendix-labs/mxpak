//// Provides version operations for mxpak.
////

import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string
import mxpak/error

/// A typed `Version` value used by the version capability.
pub type Version {
  /// The `Version` variant.
  Version(major: Int, minor: Int, patch: Int)
}

/// Parses the supplied value.
pub fn parse(str str: String) -> Result(Version, error.MissingValue) {
  let clean = string.trim(str)
  let parts = string.split(clean, ".")
  case parts {
    [maj, min, pat] -> {
      use major <- result.try(
        int.parse(maj)
        |> result.replace_error(error.MissingValue),
      )
      use minor <- result.try(
        int.parse(min)
        |> result.replace_error(error.MissingValue),
      )
      let pat_str = case string.split_once(pat, "-") {
        Ok(#(p, _)) -> p
        Error(_) -> pat
      }
      use patch <- result.try(
        int.parse(pat_str)
        |> result.replace_error(error.MissingValue),
      )
      Ok(Version(major, minor, patch))
    }
    [maj, min] -> {
      use major <- result.try(
        int.parse(maj)
        |> result.replace_error(error.MissingValue),
      )
      use minor <- result.try(
        int.parse(min)
        |> result.replace_error(error.MissingValue),
      )
      Ok(Version(major, minor, 0))
    }
    [maj] -> {
      use major <- result.try(
        int.parse(maj)
        |> result.replace_error(error.MissingValue),
      )
      Ok(Version(major, 0, 0))
    }
    _ -> Error(error.MissingValue)
  }
}

/// Serializes a semantic version.
pub fn to_string(v v: Version) -> String {
  int.to_string(v.major)
  <> "."
  <> int.to_string(v.minor)
  <> "."
  <> int.to_string(v.patch)
}

/// Compares two semantic versions.
pub fn compare(a a: Version, b b: Version) -> order.Order {
  case int.compare(a.major, b.major) {
    order.Eq ->
      case int.compare(a.minor, b.minor) {
        order.Eq -> int.compare(a.patch, b.patch)
        other -> other
      }
    other -> other
  }
}

/// a >= b
pub fn gte(a a: Version, b b: Version) -> Bool {
  case compare(a, b) {
    order.Gt | order.Eq -> True
    order.Lt -> False
  }
}

/// a > b
pub fn gt(a a: Version, b b: Version) -> Bool {
  compare(a, b) == order.Gt
}

/// a <= b
pub fn lte(a a: Version, b b: Version) -> Bool {
  case compare(a, b) {
    order.Lt | order.Eq -> True
    order.Gt -> False
  }
}

/// a < b
pub fn lt(a a: Version, b b: Version) -> Bool {
  compare(a, b) == order.Lt
}

/// a == b
pub fn eq(a a: Version, b b: Version) -> Bool {
  compare(a, b) == order.Eq
}

/// Returns the newest semantic version.
pub fn latest(
  versions versions: List(Version),
) -> Result(Version, error.MissingValue) {
  case versions {
    [] -> Error(error.MissingValue)
    [first, ..rest] ->
      Ok(
        list.fold(rest, first, fn(best, v) {
          case compare(v, best) {
            order.Gt -> v
            order.Lt | order.Eq -> best
          }
        }),
      )
  }
}
