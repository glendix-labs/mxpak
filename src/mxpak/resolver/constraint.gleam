//// Provides constraint operations for mxpak.
////

import gleam/list
import gleam/result
import gleam/string
import mxpak/error
import mxpak/resolver/version

/// A typed `Bound` value used by the constraint capability.
pub type Bound {
  /// The `Gte` variant.
  Gte(version.Version)
  /// The `Gt` variant.
  Gt(version.Version)
  /// The `Lte` variant.
  Lte(version.Version)
  /// The `Lt` variant.
  Lt(version.Version)
  /// The `Exact` variant.
  Exact(version.Version)
  /// ~> 2.5 → >= 2.5.0 and < 3.0.0
  /// ~> 2.5.1 → >= 2.5.1 and < 2.6.0
  Compatible(version.Version)
}

/// A typed `Constraint` value used by the constraint capability.
pub type Constraint {
  /// The `Constraint` variant.
  Constraint(bounds: List(Bound))
}

/// Parses the supplied value.
pub fn parse(str str: String) -> Result(Constraint, error.MissingValue) {
  let parts =
    string.split(str, " and ")
    |> list.map(string.trim)
    |> list.filter(fn(s) { s != "" })
  use bounds <- result.try(try_map(parts, parse_single_bound))
  Ok(Constraint(bounds))
}

/// Reports whether a version satisfies the constraint.
pub fn satisfies(
  constraint constraint: Constraint,
  v v: version.Version,
) -> Bool {
  list.all(constraint.bounds, fn(bound) { check_bound(bound, v) })
}

/// Filters versions by the constraint.
pub fn filter(
  constraint constraint: Constraint,
  versions versions: List(version.Version),
) -> List(version.Version) {
  list.filter(versions, fn(v) { satisfies(constraint, v) })
}

/// Resolves the latest.
pub fn resolve_latest(
  constraint constraint: Constraint,
  versions versions: List(version.Version),
) -> Result(version.Version, error.MissingValue) {
  filter(constraint, versions) |> version.latest
}

/// Creates an unconstrained version requirement.
pub fn any() -> Constraint {
  Constraint(bounds: [])
}

fn parse_single_bound(str: String) -> Result(Bound, error.MissingValue) {
  let s = string.trim(str)
  case s {
    ">= " <> rest -> {
      use v <- try_parse_version(rest)
      Ok(Gte(v))
    }
    ">" <> rest -> {
      use v <- try_parse_version(string.trim(rest))
      Ok(Gt(v))
    }
    "<= " <> rest -> {
      use v <- try_parse_version(rest)
      Ok(Lte(v))
    }
    "< " <> rest -> {
      use v <- try_parse_version(rest)
      Ok(Lt(v))
    }
    "== " <> rest -> {
      use v <- try_parse_version(rest)
      Ok(Exact(v))
    }
    "~> " <> rest -> {
      use v <- try_parse_version(rest)
      Ok(Compatible(v))
    }
    _ -> {
      case version.parse(s) {
        Ok(v) -> Ok(Exact(v))
        Error(_) -> Error(error.MissingValue)
      }
    }
  }
}

fn try_parse_version(
  str: String,
  cont: fn(version.Version) -> Result(Bound, error.MissingValue),
) -> Result(Bound, error.MissingValue) {
  case version.parse(string.trim(str)) {
    Ok(v) -> cont(v)
    Error(_) -> Error(error.MissingValue)
  }
}

fn check_bound(bound: Bound, v: version.Version) -> Bool {
  case bound {
    Gte(min) -> version.gte(v, min)
    Gt(min) -> version.gt(v, min)
    Lte(max) -> version.lte(v, max)
    Lt(max) -> version.lt(v, max)
    Exact(target) -> version.eq(v, target)
    Compatible(base) -> check_compatible(base, v)
  }
}

/// Checks whether a version is compatible with a constraint.
fn check_compatible(base: version.Version, v: version.Version) -> Bool {
  case base.patch {
    0 ->
      // ~> 2.5 → >= 2.5.0 and < 3.0.0
      version.gte(v, base) && v.major == base.major
    _ ->
      // ~> 2.5.1 → >= 2.5.1 and < 2.6.0
      version.gte(v, base) && v.major == base.major && v.minor == base.minor
  }
}

fn try_map(
  items: List(a),
  f: fn(a) -> Result(b, error.MissingValue),
) -> Result(List(b), error.MissingValue) {
  list.try_map(items, f)
}
