//// Tests mxpak behavior for mxpak.
////

import gleam/list
import gleeunit
import gleeunit/should
import mxpak/cli
import mxpak/widget

/// Runs this module's test suite.
pub fn main() -> Nil {
  gleeunit.main()
}

/// Verifies parse empty behavior.
pub fn parse_empty_test() -> Nil {
  cli.parse([])
  |> should.equal(cli.Help)
  Nil
}

/// Verifies parse version behavior.
pub fn parse_version_test() -> Nil {
  cli.parse(["--version"])
  |> should.equal(cli.Version)
  Nil
}

/// Verifies widget names are safe path segments.
pub fn widget_validate_name_test() -> Nil {
  ["DataGrid", "com.example.Widget", "Chart 2"]
  |> list.each(fn(name) { widget.validate_name(name) |> should.be_ok })
  [
    "", ".", "..", "../sibling", "nested/evil", "nested\\evil", "/absolute/evil",
    "a\u{0000}b",
  ]
  |> list.each(fn(name) { widget.validate_name(name) |> should.be_error })
  Nil
}

/// Verifies parse version short behavior.
pub fn parse_version_short_test() -> Nil {
  cli.parse(["-v"])
  |> should.equal(cli.Version)
  Nil
}

/// Verifies parse help behavior.
pub fn parse_help_test() -> Nil {
  cli.parse(["--help"])
  |> should.equal(cli.Help)
  Nil
}

/// Verifies parse install default behavior.
pub fn parse_install_default_test() -> Nil {
  cli.parse(["install"])
  |> should.equal(cli.Install("."))
  Nil
}

/// Verifies parse install with root behavior.
pub fn parse_install_with_root_test() -> Nil {
  cli.parse(["install", "/some/path"])
  |> should.equal(cli.Install("/some/path"))
  Nil
}

/// Verifies parse marketplace default behavior.
pub fn parse_marketplace_default_test() -> Nil {
  cli.parse(["marketplace"])
  |> should.equal(cli.Marketplace("."))
  Nil
}

/// Verifies parse add name only behavior.
pub fn parse_add_name_only_test() -> Nil {
  cli.parse(["add", "DataGrid"])
  |> should.equal(cli.Add("DataGrid", cli.VersionLatest))
  Nil
}

/// Verifies parse add with version behavior.
pub fn parse_add_with_version_test() -> Nil {
  cli.parse(["add", "DataGrid", "--version", "2.0.0"])
  |> should.equal(cli.Add("DataGrid", cli.VersionSpecified("2.0.0")))
  Nil
}

/// Verifies parse remove behavior.
pub fn parse_remove_test() -> Nil {
  cli.parse(["remove", "DataGrid"])
  |> should.equal(cli.Remove("DataGrid"))
  Nil
}

/// Verifies parse update all behavior.
pub fn parse_update_all_test() -> Nil {
  cli.parse(["update"])
  |> should.equal(cli.Update(""))
  Nil
}

/// Verifies parse update specific behavior.
pub fn parse_update_specific_test() -> Nil {
  cli.parse(["update", "DataGrid"])
  |> should.equal(cli.Update("DataGrid"))
  Nil
}

/// Verifies parse cache clean behavior.
pub fn parse_cache_clean_test() -> Nil {
  cli.parse(["cache", "clean"])
  |> should.equal(cli.CacheClean)
  Nil
}

/// Verifies parse unknown behavior.
pub fn parse_unknown_test() -> Nil {
  cli.parse(["foo"])
  |> should.equal(cli.Unknown("foo"))
  Nil
}

/// Verifies parse audit default behavior.
pub fn parse_audit_default_test() -> Nil {
  cli.parse(["audit"])
  |> should.equal(cli.Audit("."))
  Nil
}

/// Verifies parse list default behavior.
pub fn parse_list_default_test() -> Nil {
  cli.parse(["list"])
  |> should.equal(cli.List("."))
  Nil
}

/// Verifies parse info behavior.
pub fn parse_info_test() -> Nil {
  cli.parse(["info", "Charts"])
  |> should.equal(cli.Info("Charts"))
  Nil
}
