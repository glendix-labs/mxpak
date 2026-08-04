//// Provides pagination operations for mxpak.
////

import gleam/int
import gleam/list
import gleam/option
import gleam/string
import mxpak/marketplace/state
import mxpak/registry/content_api

/// Returns the active filtered or complete widget source.
pub fn get_source(model model: state.Model) -> List(content_api.Widget) {
  case model.filtered {
    option.Some(f) -> f
    option.None -> model.all_widgets
  }
}

/// Returns the widgets visible on the current page.
pub fn current_page_items(
  model model: state.Model,
) -> List(content_api.Widget) {
  get_source(model)
  |> list.drop(model.page_index * state.display_size)
  |> list.take(state.display_size)
}

/// Returns the formatted total page count.
pub fn total_pages_str(model model: state.Model) -> String {
  let len = list.length(get_source(model))
  let total = case len {
    0 -> 1
    _ -> { len + state.display_size - 1 } / state.display_size
  }
  let suffix = case model.all_loaded || option.is_some(model.filtered) {
    True -> ""
    False -> "+"
  }
  int.to_string(total) <> suffix
}

/// Filters the widgets.
pub fn filter_widgets(
  widgets widgets: List(content_api.Widget),
  query query: String,
) -> List(content_api.Widget) {
  let q = string.lowercase(query)
  list.filter(widgets, fn(w) {
    let name = string.lowercase(option.unwrap(w.name, ""))
    let publisher = string.lowercase(option.unwrap(w.publisher, ""))
    string.contains(name, q) || string.contains(publisher, q)
  })
}
