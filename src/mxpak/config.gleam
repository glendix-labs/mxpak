//// Provides config operations for mxpak.
////

import gleam/option
import mxpak/config/env_reader
import mxpak/config/toml_reader
import mxpak/config/toml_writer
import mxpak/error
import mxpak/widget

/// Reads project package configuration.
pub fn read(
  project_root project_root: String,
) -> Result(toml_reader.ProjectConfig, error.Error) {
  toml_reader.read_config(project_root)
}

/// Returns the configured Mendix personal access token.
pub fn get_pat(
  project_root project_root: String,
) -> Result(option.Option(String), error.Error) {
  env_reader.get("MENDIX_PAT", project_root)
}

/// Writes the widget.
pub fn write_widget(
  project_root project_root: String,
  name name: String,
  version version: String,
  content_id content_id: option.Option(Int),
  s3_id s3_id: option.Option(String),
) -> Result(Nil, error.Error) {
  toml_writer.write_widget(project_root, name, version, content_id, s3_id)
}

/// Removes the widget.
pub fn remove_widget(
  project_root project_root: String,
  name name: String,
) -> Result(Nil, error.Error) {
  toml_writer.remove_widget(project_root, name)
}

/// Reads the meta.
pub fn read_meta(
  path path: String,
) -> Result(toml_reader.WidgetConfig, error.Error) {
  toml_reader.read_meta_toml(path)
}

/// Writes the meta.
pub fn write_meta(
  path path: String,
  version version: String,
  id id: option.Option(Int),
  kind kind: widget.Kind,
) -> Result(Nil, error.Error) {
  toml_writer.write_meta_toml(path, version, id, kind)
}
