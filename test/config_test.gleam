//// Tests config behavior for mxpak.
////

import gleam/dict
import gleam/list
import gleam/option
import gleam/string
import gleeunit
import gleeunit/should
import mxpak/config/env_reader
import mxpak/config/toml_reader
import mxpak/config/toml_writer
import mxpak/widget
import simplifile

/// Runs this module's test suite.
pub fn main() -> Nil {
  gleeunit.main()
}

/// Verifies read config with widgets behavior.
pub fn read_config_with_widgets_test() -> Nil {
  let dir = "build/test_tmp/reader1"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let toml =
    "name = \"test\"\nversion = \"1.0.0\"\n\n[tools.mxpak.widgets.DataGrid]\nversion = \"2.5.0\"\nid = 12345\ns3_id = \"abc/def\"\n"
  simplifile.write(dir <> "/gleam.toml", toml)
  |> should.be_ok
  let config =
    toml_reader.read_config(dir)
    |> should.be_ok
  { dict.size(config.widgets) == 1 }
  |> should.be_true
  let widget =
    dict.get(config.widgets, "DataGrid")
    |> should.be_ok
  { widget.version == "2.5.0" }
  |> should.be_true
  widget.id
  |> should.equal(option.Some(12_345))
  widget.s3_id
  |> should.equal(option.Some("abc/def"))
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies read config empty widgets behavior.
pub fn read_config_empty_widgets_test() -> Nil {
  let dir = "build/test_tmp/reader2"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(dir <> "/gleam.toml", "name = \"test\"\n")
  |> should.be_ok
  let config =
    toml_reader.read_config(dir)
    |> should.be_ok
  { dict.size(config.widgets) == 0 }
  |> should.be_true
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies read config with mendix version behavior.
pub fn read_config_with_mendix_version_test() -> Nil {
  let dir = "build/test_tmp/reader3"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let toml = "name = \"test\"\n\n[tools.mxpak]\nmendix_version = \"10.12.0\"\n"
  simplifile.write(dir <> "/gleam.toml", toml)
  |> should.be_ok
  let config =
    toml_reader.read_config(dir)
    |> should.be_ok
  config.mendix_version
  |> should.equal(option.Some("10.12.0"))
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies read config multiple widgets behavior.
pub fn read_config_multiple_widgets_test() -> Nil {
  let dir = "build/test_tmp/reader4"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let toml =
    "name = \"test\"\n\n[tools.mxpak.widgets.A]\nversion = \"1.0.0\"\n\n[tools.mxpak.widgets.B]\nversion = \"2.0.0\"\nclassic = true\n"
  simplifile.write(dir <> "/gleam.toml", toml)
  |> should.be_ok
  let config =
    toml_reader.read_config(dir)
    |> should.be_ok
  { dict.size(config.widgets) == 2 }
  |> should.be_true
  let b =
    dict.get(config.widgets, "B")
    |> should.be_ok
  b.kind
  |> should.equal(widget.Classic)
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies read config missing file behavior.
pub fn read_config_missing_file_test() -> Nil {
  toml_reader.read_config("build/test_tmp/nonexistent")
  |> should.be_error
  Nil
}

/// Verifies read meta toml behavior.
pub fn read_meta_toml_test() -> Nil {
  let dir = "build/test_tmp/meta1"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let meta = "version = \"3.0.0\"\nid = 999\nclassic = true\n"
  simplifile.write(dir <> "/meta.toml", meta)
  |> should.be_ok
  let config =
    toml_reader.read_meta_toml(dir <> "/meta.toml")
    |> should.be_ok
  { config.version == "3.0.0" }
  |> should.be_true
  config.id
  |> should.equal(option.Some(999))
  config.kind
  |> should.equal(widget.Classic)
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies write widget new section behavior.
pub fn write_widget_new_section_test() -> Nil {
  let dir = "build/test_tmp/writer1"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(dir <> "/gleam.toml", "name = \"test\"\n")
  |> should.be_ok
  toml_writer.write_widget(
    dir,
    "Charts",
    "4.0.0",
    option.Some(100),
    option.None,
  )
  |> should.be_ok
  let content =
    simplifile.read(dir <> "/gleam.toml")
    |> should.be_ok
  content
  |> contains("[tools.mxpak.widgets.Charts]")
  |> should.be_true
  content
  |> contains("version = \"4.0.0\"")
  |> should.be_true
  content
  |> contains("id = 100")
  |> should.be_true
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies write widget update existing behavior.
pub fn write_widget_update_existing_test() -> Nil {
  let dir = "build/test_tmp/writer2"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let toml =
    "name = \"test\"\n\n[tools.mxpak.widgets.Charts]\nversion = \"3.0.0\"\n"
  simplifile.write(dir <> "/gleam.toml", toml)
  |> should.be_ok
  toml_writer.write_widget(dir, "Charts", "4.0.0", option.None, option.None)
  |> should.be_ok
  let content =
    simplifile.read(dir <> "/gleam.toml")
    |> should.be_ok
  content
  |> contains("version = \"4.0.0\"")
  |> should.be_true
  content
  |> contains("version = \"3.0.0\"")
  |> should.be_false
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies write widget quoted name behavior.
pub fn write_widget_quoted_name_test() -> Nil {
  let dir = "build/test_tmp/writer3"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(dir <> "/gleam.toml", "name = \"test\"\n")
  |> should.be_ok
  toml_writer.write_widget(
    dir,
    "Data Widgets",
    "1.0.0",
    option.None,
    option.None,
  )
  |> should.be_ok
  let content =
    simplifile.read(dir <> "/gleam.toml")
    |> should.be_ok
  content
  |> contains("[tools.mxpak.widgets.\"Data Widgets\"]")
  |> should.be_true
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies remove widget behavior.
pub fn remove_widget_test() -> Nil {
  let dir = "build/test_tmp/writer4"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let toml =
    "name = \"test\"\n\n[tools.mxpak.widgets.A]\nversion = \"1.0.0\"\n\n[tools.mxpak.widgets.B]\nversion = \"2.0.0\"\n"
  simplifile.write(dir <> "/gleam.toml", toml)
  |> should.be_ok
  toml_writer.remove_widget(dir, "A")
  |> should.be_ok
  let content =
    simplifile.read(dir <> "/gleam.toml")
    |> should.be_ok
  content
  |> contains("[tools.mxpak.widgets.A]")
  |> should.be_false
  content
  |> contains("[tools.mxpak.widgets.B]")
  |> should.be_true
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies write meta toml behavior.
pub fn write_meta_toml_test() -> Nil {
  let dir = "build/test_tmp/meta_w1"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  toml_writer.write_meta_toml(
    dir <> "/meta.toml",
    "5.0.0",
    option.Some(42),
    widget.Pluggable,
  )
  |> should.be_ok
  let content =
    simplifile.read(dir <> "/meta.toml")
    |> should.be_ok
  content
  |> contains("version = \"5.0.0\"")
  |> should.be_true
  content
  |> contains("id = 42")
  |> should.be_true
  content
  |> contains("classic")
  |> should.be_false
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies write meta toml classic behavior.
pub fn write_meta_toml_classic_test() -> Nil {
  let dir = "build/test_tmp/meta_w2"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  toml_writer.write_meta_toml(
    dir <> "/meta.toml",
    "1.0.0",
    option.None,
    widget.Classic,
  )
  |> should.be_ok
  let content =
    simplifile.read(dir <> "/meta.toml")
    |> should.be_ok
  content
  |> contains("classic = true")
  |> should.be_true
  content
  |> contains("id")
  |> should.be_false
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies env reader dotenv behavior.
pub fn env_reader_dotenv_test() -> Nil {
  let dir = "build/test_tmp/env1"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(
    dir <> "/.env",
    "# 코멘트\nMENDIX_PAT=test_token_123\nOTHER=val\n",
  )
  |> should.be_ok
  env_reader.get("MENDIX_PAT", dir)
  |> should.be_ok
  |> should.equal(option.Some("test_token_123"))
  env_reader.get("OTHER", dir)
  |> should.be_ok
  |> should.equal(option.Some("val"))
  env_reader.get("MISSING", dir)
  |> should.be_ok
  |> should.be_none
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies env reader quoted value behavior.
pub fn env_reader_quoted_value_test() -> Nil {
  let dir = "build/test_tmp/env2"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(dir <> "/.env", "KEY=\"quoted_value\"\n")
  |> should.be_ok
  env_reader.get("KEY", dir)
  |> should.be_ok
  |> should.equal(option.Some("quoted_value"))
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies hostile dotenv values are preserved as inert data.
pub fn env_reader_hostile_value_test() -> Nil {
  let dir = "build/test_tmp/env3"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(
    dir <> "/.env",
    "MENDIX_PAT=$(touch /tmp/mendraw-pwned)`id`'a\"b&whoami\n",
  )
  |> should.be_ok
  env_reader.get("MENDIX_PAT", dir)
  |> should.be_ok
  |> should.equal(option.Some("$(touch /tmp/mendraw-pwned)`id`'a\"b&whoami"))
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies only one surrounding quote pair is removed.
pub fn env_reader_inner_quotes_are_preserved_test() -> Nil {
  let dir = "build/test_tmp/env4"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(dir <> "/.env", "KEY=\"a\"b\"\n")
  |> should.be_ok
  env_reader.get("KEY", dir)
  |> should.be_ok
  |> should.equal(option.Some("a\"b"))
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies env reader missing file behavior.
pub fn env_reader_missing_file_test() -> Nil {
  env_reader.get("KEY", "build/test_tmp/no_env")
  |> should.be_ok
  |> should.be_none
  Nil
}

/// Verifies traversal widget names are rejected at the configuration boundary.
pub fn read_config_rejects_path_traversal_names_test() -> Nil {
  let cases = [
    #("../../evil", "parent"),
    #("/absolute/evil", "absolute"),
    #("..", "dot"),
    #("nested/evil", "nested"),
    #("nested\\evil", "backslash"),
  ]
  list.each(cases, fn(pair) {
    let #(name, slug) = pair
    let dir = "build/test_tmp/traversal_" <> slug
    simplifile.create_directory_all(dir)
    |> should.be_ok
    simplifile.write(
      dir <> "/gleam.toml",
      "[tools.mxpak.widgets.\"" <> name <> "\"]\nversion = \"1.0.0\"\n",
    )
    |> should.be_ok
    toml_reader.read_config(dir)
    |> should.be_error
    simplifile.delete(dir)
    |> should.be_ok
  })
  Nil
}

/// Verifies legal dotted widget names remain accepted.
pub fn read_config_accepts_dotted_names_test() -> Nil {
  let dir = "build/test_tmp/dotted_name"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(
    dir <> "/gleam.toml",
    "[tools.mxpak.widgets.\"com.example.Widget\"]\nversion = \"1.0.0\"\n",
  )
  |> should.be_ok
  toml_reader.read_config(dir)
  |> should.be_ok
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies hostile strings round-trip through written widget configuration.
pub fn write_widget_escapes_hostile_strings_test() -> Nil {
  let dir = "build/test_tmp/escaping"
  let hostile_version = "1.0\"0\\n\u{0009}x"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  simplifile.write(dir <> "/gleam.toml", "name = \"host\"\n")
  |> should.be_ok
  toml_writer.write_widget(
    dir,
    "Data Grid",
    hostile_version,
    option.Some(7),
    option.Some("a\\b\"c"),
  )
  |> should.be_ok
  let config = toml_reader.read_config(dir) |> should.be_ok
  let widget = dict.get(config.widgets, "Data Grid") |> should.be_ok
  widget.version
  |> should.equal(hostile_version)
  widget.s3_id
  |> should.equal(option.Some("a\\b\"c"))
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

fn contains(haystack: String, needle: String) -> Bool {
  string.contains(haystack, needle)
}
