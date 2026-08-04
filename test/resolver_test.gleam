//// Tests resolver behavior for mxpak.
////

import gleam/order
import gleeunit/should
import mxpak/error
import mxpak/resolver/constraint
import mxpak/resolver/version

/// Verifies parse full behavior.
pub fn parse_full_test() -> Nil {
  let v =
    version.parse("1.2.3")
    |> should.be_ok
  { v == version.Version(1, 2, 3) }
  |> should.be_true
  Nil
}

/// Verifies parse two part behavior.
pub fn parse_two_part_test() -> Nil {
  let v =
    version.parse("2.5")
    |> should.be_ok
  { v == version.Version(2, 5, 0) }
  |> should.be_true
  Nil
}

/// Verifies parse one part behavior.
pub fn parse_one_part_test() -> Nil {
  let v =
    version.parse("3")
    |> should.be_ok
  { v == version.Version(3, 0, 0) }
  |> should.be_true
  Nil
}

/// Verifies parse with prerelease behavior.
pub fn parse_with_prerelease_test() -> Nil {
  let v =
    version.parse("1.0.0-beta")
    |> should.be_ok
  { v == version.Version(1, 0, 0) }
  |> should.be_true
  Nil
}

/// Verifies parse invalid behavior.
pub fn parse_invalid_test() -> Nil {
  version.parse("abc")
  |> should.equal(Error(error.MissingValue))
  Nil
}

/// Verifies compare equal behavior.
pub fn compare_equal_test() -> Nil {
  let a =
    version.parse("1.2.3")
    |> should.be_ok
  let b =
    version.parse("1.2.3")
    |> should.be_ok
  { version.compare(a, b) == order.Eq }
  |> should.be_true
  Nil
}

/// Verifies compare major behavior.
pub fn compare_major_test() -> Nil {
  let a =
    version.parse("2.0.0")
    |> should.be_ok
  let b =
    version.parse("1.9.9")
    |> should.be_ok
  { version.compare(a, b) == order.Gt }
  |> should.be_true
  Nil
}

/// Verifies compare minor behavior.
pub fn compare_minor_test() -> Nil {
  let a =
    version.parse("1.3.0")
    |> should.be_ok
  let b =
    version.parse("1.2.9")
    |> should.be_ok
  { version.compare(a, b) == order.Gt }
  |> should.be_true
  Nil
}

/// Verifies compare patch behavior.
pub fn compare_patch_test() -> Nil {
  let a =
    version.parse("1.2.4")
    |> should.be_ok
  let b =
    version.parse("1.2.3")
    |> should.be_ok
  version.gt(a, b)
  |> should.be_true
  Nil
}

/// Verifies to string behavior.
pub fn to_string_test() -> Nil {
  { version.to_string(version.Version(1, 2, 3)) == "1.2.3" }
  |> should.be_true
  Nil
}

/// Verifies latest behavior.
pub fn latest_test() -> Nil {
  let versions = [
    version.Version(1, 0, 0),
    version.Version(3, 1, 0),
    version.Version(2, 5, 0),
  ]
  let best =
    version.latest(versions)
    |> should.be_ok
  { best == version.Version(3, 1, 0) }
  |> should.be_true
  Nil
}

/// Verifies latest empty behavior.
pub fn latest_empty_test() -> Nil {
  version.latest([])
  |> should.equal(Error(error.MissingValue))
  Nil
}

/// Verifies parse gte behavior.
pub fn parse_gte_test() -> Nil {
  let c =
    constraint.parse(">= 2.0.0")
    |> should.be_ok
  let v =
    version.parse("2.5.0")
    |> should.be_ok
  constraint.satisfies(c, v)
  |> should.be_true
  Nil
}

/// Verifies parse lt behavior.
pub fn parse_lt_test() -> Nil {
  let c =
    constraint.parse("< 3.0.0")
    |> should.be_ok
  let v =
    version.parse("2.9.9")
    |> should.be_ok
  constraint.satisfies(c, v)
  |> should.be_true
  let v3 =
    version.parse("3.0.0")
    |> should.be_ok
  constraint.satisfies(c, v3)
  |> should.be_false
  Nil
}

/// Verifies parse range behavior.
pub fn parse_range_test() -> Nil {
  let c =
    constraint.parse(">= 2.0.0 and < 3.0.0")
    |> should.be_ok
  let v1 =
    version.parse("2.5.0")
    |> should.be_ok
  let v2 =
    version.parse("3.0.0")
    |> should.be_ok
  let v3 =
    version.parse("1.9.0")
    |> should.be_ok
  constraint.satisfies(c, v1)
  |> should.be_true
  constraint.satisfies(c, v2)
  |> should.be_false
  constraint.satisfies(c, v3)
  |> should.be_false
  Nil
}

/// Verifies parse exact behavior.
pub fn parse_exact_test() -> Nil {
  let c =
    constraint.parse("== 1.5.0")
    |> should.be_ok
  let v1 =
    version.parse("1.5.0")
    |> should.be_ok
  let v2 =
    version.parse("1.5.1")
    |> should.be_ok
  constraint.satisfies(c, v1)
  |> should.be_true
  constraint.satisfies(c, v2)
  |> should.be_false
  Nil
}

/// Verifies parse compatible major behavior.
pub fn parse_compatible_major_test() -> Nil {
  // ~> 2.5 → >= 2.5.0 and < 3.0.0
  let c =
    constraint.parse("~> 2.5")
    |> should.be_ok
  let v1 =
    version.parse("2.5.0")
    |> should.be_ok
  let v2 =
    version.parse("2.9.9")
    |> should.be_ok
  let v3 =
    version.parse("3.0.0")
    |> should.be_ok
  constraint.satisfies(c, v1)
  |> should.be_true
  constraint.satisfies(c, v2)
  |> should.be_true
  constraint.satisfies(c, v3)
  |> should.be_false
  Nil
}

/// Verifies parse compatible minor behavior.
pub fn parse_compatible_minor_test() -> Nil {
  // ~> 2.5.1 → >= 2.5.1 and < 2.6.0
  let c =
    constraint.parse("~> 2.5.1")
    |> should.be_ok
  let v1 =
    version.parse("2.5.1")
    |> should.be_ok
  let v2 =
    version.parse("2.5.9")
    |> should.be_ok
  let v3 =
    version.parse("2.6.0")
    |> should.be_ok
  constraint.satisfies(c, v1)
  |> should.be_true
  constraint.satisfies(c, v2)
  |> should.be_true
  constraint.satisfies(c, v3)
  |> should.be_false
  Nil
}

/// Verifies resolve latest behavior.
pub fn resolve_latest_test() -> Nil {
  let c =
    constraint.parse(">= 2.0.0 and < 3.0.0")
    |> should.be_ok
  let versions = [
    version.Version(1, 9, 0),
    version.Version(2, 1, 0),
    version.Version(2, 5, 0),
    version.Version(3, 0, 0),
  ]
  let best =
    constraint.resolve_latest(c, versions)
    |> should.be_ok
  { best == version.Version(2, 5, 0) }
  |> should.be_true
  Nil
}

/// Verifies any constraint behavior.
pub fn any_constraint_test() -> Nil {
  let c = constraint.any()
  let v =
    version.parse("99.99.99")
    |> should.be_ok
  constraint.satisfies(c, v)
  |> should.be_true
  Nil
}
