//// Provides metadata operations for mxpak.
////

import gleam/option
import mxpak/config/toml_reader
import mxpak/config/toml_writer
import mxpak/error
import mxpak/widget

/// Reads cached widget metadata.
pub fn read(
  path path: String,
) -> Result(toml_reader.WidgetConfig, error.Error) {
  toml_reader.read_meta_toml(path)
}

/// Writes cached widget metadata.
pub fn write(
  path path: String,
  version version: String,
  id id: option.Option(Int),
  kind kind: widget.Kind,
) -> Result(Nil, error.Error) {
  toml_writer.write_meta_toml(path, version, id, kind)
}
