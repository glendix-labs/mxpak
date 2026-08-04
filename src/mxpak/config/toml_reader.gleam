//// Provides toml reader operations for mxpak.
////

import gleam/dict
import gleam/option
import gleam/result
import mxpak/error
import mxpak/widget
import simplifile
import tom

/// Selects how resolved widgets are installed into a project.
pub type WidgetMode {
  /// Extracts widget package contents into the project cache.
  Extract
  /// Keeps widget packages as MPK files in the configured widget directory.
  Mpk
}

/// Declares one package managed by mxpak.
pub type WidgetConfig {
  /// Stores the requested version and optional Marketplace identifiers.
  WidgetConfig(
    version: String,
    id: option.Option(Int),
    s3_id: option.Option(String),
    kind: widget.Kind,
  )
}

/// Declares mxpak package installation settings for one project.
pub type ProjectConfig {
  /// Stores the target Mendix version, installation mode, and packages.
  ProjectConfig(
    mendix_version: option.Option(String),
    mode: WidgetMode,
    widgets_dir: String,
    widgets: dict.Dict(String, WidgetConfig),
  )
}

/// Reads `[tools.mxpak]` from a project's `gleam.toml`.
pub fn read_config(
  project_root project_root: String,
) -> Result(ProjectConfig, error.Error) {
  let toml_path = project_root <> "/gleam.toml"
  use content <- result.try(
    simplifile.read(toml_path)
    |> result.map_error(fn(_) {
      error.configuration("gleam.toml 읽기 실패: " <> toml_path)
    }),
  )
  use parsed <- result.try(
    tom.parse(content)
    |> result.map_error(fn(_) { error.configuration("gleam.toml 파싱 실패") }),
  )
  extract_project_config(parsed)
}

/// Reads metadata written beside an extracted package.
pub fn read_meta_toml(path path: String) -> Result(WidgetConfig, error.Error) {
  use content <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(_) {
      error.configuration("meta.toml 읽기 실패: " <> path)
    }),
  )
  use parsed <- result.try(
    tom.parse(content)
    |> result.map_error(fn(_) {
      error.configuration("meta.toml 파싱 실패: " <> path)
    }),
  )
  Ok(parse_single_widget(parsed))
}

/// Decodes mxpak tool configuration from parsed TOML.
fn extract_project_config(
  toml: dict.Dict(String, tom.Toml),
) -> Result(ProjectConfig, error.Error) {
  let mendix_version =
    tom.get_string(toml, ["tools", "mxpak", "mendix_version"])
    |> option.from_result
  use mode <- result.try(
    tom.get_string(toml, ["tools", "mxpak", "mode"])
    |> result.unwrap("extract")
    |> parse_widget_mode,
  )
  let widgets_dir =
    tom.get_string(toml, ["tools", "mxpak", "widgets_dir"])
    |> result.unwrap("widgets")
  let widgets = case tom.get_table(toml, ["tools", "mxpak", "widgets"]) {
    Ok(widgets_table) -> parse_widgets(widgets_table)
    Error(_) -> dict.new()
  }
  Ok(ProjectConfig(
    mendix_version: mendix_version,
    mode: mode,
    widgets_dir: widgets_dir,
    widgets: widgets,
  ))
}

fn parse_widgets(
  table: dict.Dict(String, tom.Toml),
) -> dict.Dict(String, WidgetConfig) {
  dict.fold(table, dict.new(), fn(acc, name, value) {
    case value {
      tom.Table(widget_table) | tom.InlineTable(widget_table) ->
        dict.insert(acc, name, parse_single_widget(widget_table))
      tom.Int(_)
      | tom.Float(_)
      | tom.Infinity(_)
      | tom.Nan(_)
      | tom.Bool(_)
      | tom.String(_)
      | tom.Date(_)
      | tom.Time(_)
      | tom.DateTime(..)
      | tom.Array(_)
      | tom.ArrayOfTables(_) -> acc
    }
  })
}

fn parse_single_widget(table: dict.Dict(String, tom.Toml)) -> WidgetConfig {
  let version = tom.get_string(table, ["version"]) |> result.unwrap("")
  let id = tom.get_int(table, ["id"]) |> option.from_result
  let s3_id = tom.get_string(table, ["s3_id"]) |> option.from_result
  let kind = case tom.get_bool(table, ["classic"]) {
    Ok(True) -> widget.Classic
    Ok(False) | Error(_) -> widget.Pluggable
  }
  WidgetConfig(version: version, id: id, s3_id: s3_id, kind: kind)
}

fn parse_widget_mode(value: String) -> Result(WidgetMode, error.Error) {
  case value {
    "extract" -> Ok(Extract)
    "mpk" -> Ok(Mpk)
    unsupported ->
      Error(error.configuration("지원하지 않는 tools.mxpak.mode: " <> unsupported))
  }
}
