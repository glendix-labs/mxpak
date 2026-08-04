//// Tests mpk behavior for mxpak.
////

import gleam/list
import gleam/option
import gleam/string
import gleeunit/should
import mxpak/error
import mxpak/mpk/metadata
import mxpak/mpk/xml
import mxpak/mpk/zip
import mxpak/widget
import simplifile

/// Verifies zip extract invalid binary behavior.
pub fn zip_extract_invalid_binary_test() -> Nil {
  zip.extract(<<"not a zip":utf8>>)
  |> should.be_error
  |> error.message
  |> string.is_empty
  |> should.be_false
  Nil
}

/// Verifies zip extract file from invalid behavior.
pub fn zip_extract_file_from_invalid_test() -> Nil {
  zip.extract_file(<<"bad":utf8>>, "foo.txt")
  |> should.be_error
  Nil
}

/// Verifies parse widget name behavior.
pub fn parse_widget_name_test() -> Nil {
  let xml = "<widget><name>DataGrid</name></widget>"
  xml.parse_widget_name(xml)
  |> should.equal(Ok("DataGrid"))
  Nil
}

/// Verifies parse widget name missing behavior.
pub fn parse_widget_name_missing_test() -> Nil {
  xml.parse_widget_name("<widget></widget>")
  |> should.be_error
  Nil
}

/// Verifies extract widget file paths behavior.
pub fn extract_widget_file_paths_test() -> Nil {
  let package_xml =
    "<package><clientModule><widgetFile path=\"com/example/Widget.mjs\"/><widgetFile path=\"com/example/Other.mjs\"/></clientModule></package>"
  let paths =
    xml.extract_widget_file_paths(package_xml)
    |> should.be_ok
  { paths == ["com/example/Widget.mjs", "com/example/Other.mjs"] }
  |> should.be_true
  Nil
}

/// Verifies extract widget file paths empty behavior.
pub fn extract_widget_file_paths_empty_test() -> Nil {
  xml.extract_widget_file_paths("<package></package>")
  |> should.be_ok
  |> should.equal([])
  Nil
}

/// Verifies parse properties behavior.
pub fn parse_properties_test() -> Nil {
  let widget_xml =
    "<widget><property key=\"dataSource\" required=\"true\"/><property key=\"label\" required=\"false\">desc</property></widget>"
  let props =
    xml.parse_properties(widget_xml)
    |> should.be_ok
  {
    case props {
      [first, second] -> {
        first.key == "dataSource"
        && first.required == True
        && second.key == "label"
        && second.required == False
      }
      _ -> False
    }
  }
  |> should.be_true
  Nil
}

/// Verifies parse properties no required behavior.
pub fn parse_properties_no_required_test() -> Nil {
  let widget_xml = "<widget><property key=\"value\"/></widget>"
  let props =
    xml.parse_properties(widget_xml)
    |> should.be_ok
  list.length(props)
  |> should.equal(1)
  let prop =
    list.first(props)
    |> should.be_ok
  { prop.key == "value" }
  |> should.be_true
  prop.required
  |> should.be_false
  Nil
}

/// Verifies to safe identifier behavior.
pub fn to_safe_identifier_test() -> Nil {
  { xml.to_safe_identifier("Progress Bar") == "ProgressBar" }
  |> should.be_true
  { xml.to_safe_identifier("Data-Grid") == "DataGrid" }
  |> should.be_true
  { xml.to_safe_identifier("Normal") == "Normal" }
  |> should.be_true
  Nil
}

/// Verifies to module file name behavior.
pub fn to_module_file_name_test() -> Nil {
  { xml.to_module_file_name("Progress Bar") == "progress_bar" }
  |> should.be_true
  { xml.to_module_file_name("DataGrid") == "data_grid" }
  |> should.be_true
  Nil
}

/// Verifies to snake case behavior.
pub fn to_snake_case_test() -> Nil {
  { xml.to_snake_case("camelCase") == "camel_case" }
  |> should.be_true
  { xml.to_snake_case("HTTPClient") == "http_client" }
  |> should.be_true
  { xml.to_snake_case("simpleTest") == "simple_test" }
  |> should.be_true
  Nil
}

/// Verifies to gleam var behavior.
pub fn to_gleam_var_test() -> Nil {
  { xml.to_gleam_var("dataSource") == "data_source" }
  |> should.be_true
  { xml.to_gleam_var("type") == "type_" }
  |> should.be_true
  { xml.to_gleam_var("import") == "import_" }
  |> should.be_true
  { xml.to_gleam_var("normalName") == "normal_name" }
  |> should.be_true
  Nil
}

/// Verifies metadata write read roundtrip behavior.
pub fn metadata_write_read_roundtrip_test() -> Nil {
  let dir = "build/test_tmp/meta_rt"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let path = dir <> "/meta.toml"
  metadata.write(path, "2.0.0", option.Some(42), widget.Pluggable)
  |> should.be_ok
  let config =
    metadata.read(path)
    |> should.be_ok
  { config.version == "2.0.0" }
  |> should.be_true
  config.id
  |> should.equal(option.Some(42))
  config.kind
  |> should.equal(widget.Pluggable)
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}

/// Verifies metadata classic roundtrip behavior.
pub fn metadata_classic_roundtrip_test() -> Nil {
  let dir = "build/test_tmp/meta_rt2"
  simplifile.create_directory_all(dir)
  |> should.be_ok
  let path = dir <> "/meta.toml"
  metadata.write(path, "1.0.0", option.None, widget.Classic)
  |> should.be_ok
  let config =
    metadata.read(path)
    |> should.be_ok
  { config.version == "1.0.0" }
  |> should.be_true
  config.id
  |> should.be_none
  config.kind
  |> should.equal(widget.Classic)
  simplifile.delete(dir)
  |> should.be_ok
  Nil
}
