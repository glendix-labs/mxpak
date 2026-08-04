//// Provides loader operations for mxpak.
////

import gleam/erlang/process
import gleam/list
import mxpak/registry/content_api
import mxpak/registry/content_transport

/// A typed `LoaderMsg` value used by the loader capability.
pub type LoaderMsg {
  /// The `LoaderUpdate` variant.
  LoaderUpdate(widgets: List(content_api.Widget), offset: Int, done: Bool)
}

/// A typed `LoaderHandle` value used by the loader capability.
pub type LoaderHandle {
  /// The `LoaderHandle` variant.
  LoaderHandle(control: process.Subject(LoaderControl))
}

/// A typed `LoaderControl` value used by the loader capability.
pub type LoaderControl {
  /// The `StopLoader` variant.
  StopLoader
}

/// Starts this module's managed operation.
pub fn start(
  pat pat: String,
  initial_offset initial_offset: Int,
  initial_widgets initial_widgets: List(content_api.Widget),
  notify notify: process.Subject(LoaderMsg),
  ready ready: process.Subject(LoaderHandle),
) -> Nil {
  process.spawn(fn() {
    let control = process.new_subject()
    process.send(ready, LoaderHandle(control))
    loader_loop(pat, initial_offset, initial_widgets, notify, control)
  })
  Nil
}

/// Stops this module's managed operation.
pub fn stop(handle handle: LoaderHandle) -> Nil {
  process.send(handle.control, StopLoader)
}

fn loader_loop(
  pat: String,
  offset: Int,
  widgets: List(content_api.Widget),
  notify: process.Subject(LoaderMsg),
  control: process.Subject(LoaderControl),
) -> Nil {
  case process.receive(control, 0) {
    Ok(StopLoader) -> Nil
    Error(_) -> {
      case
        content_transport.fetch_content_page(
          pat,
          offset,
          content_api.fetch_size,
        )
      {
        Ok(page) -> {
          let new_widgets = list.append(widgets, page.widgets)
          let new_offset = offset + content_api.fetch_size
          process.send(
            notify,
            LoaderUpdate(new_widgets, new_offset, page.all_done),
          )
          case page.all_done {
            True -> Nil
            False -> loader_loop(pat, new_offset, new_widgets, notify, control)
          }
        }
        Error(_) -> {
          process.send(notify, LoaderUpdate(widgets, offset, True))
        }
      }
    }
  }
}
