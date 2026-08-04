//// Provides process manager operations for mxpak.
////

import gleam/erlang/process
import gleam/option
import mxpak/marketplace/loader
import mxpak/marketplace/state

/// Starts the background Marketplace loader when required.
pub fn start_loader(model model: state.Model) -> state.Model {
  case model.all_loaded {
    True -> model
    False -> {
      case model.shore_subject {
        option.Some(shore_subject) -> {
          let handle_ready = process.new_subject()
          let pat = model.pat
          let offset = model.offset
          let widgets = model.all_widgets
          process.spawn(fn() {
            let loader_subject = process.new_subject()
            let loader_handle_ready = process.new_subject()
            loader.start(
              pat,
              offset,
              widgets,
              loader_subject,
              loader_handle_ready,
            )
            case process.receive(loader_handle_ready, 10_000) {
              Ok(handle) -> {
                process.send(handle_ready, handle)
                relay_loop(loader_subject, shore_subject)
              }
              Error(_) -> Nil
            }
          })
          case process.receive(handle_ready, 15_000) {
            Ok(handle) -> state.Model(..model, loader: option.Some(handle))
            Error(_) -> model
          }
        }
        option.None -> model
      }
    }
  }
}

/// Stops the active Marketplace loader.
pub fn stop_loader(model model: state.Model) -> state.Model {
  case model.loader {
    option.Some(handle) -> {
      loader.stop(handle)
      state.Model(..model, loader: option.None)
    }
    option.None -> model
  }
}

/// Stops background Marketplace work before exit.
pub fn cleanup(model model: state.Model) -> Nil {
  case model.loader {
    option.Some(handle) -> loader.stop(handle)
    option.None -> Nil
  }
}

fn relay_loop(
  from: process.Subject(loader.LoaderMsg),
  to: process.Subject(state.Msg),
) -> Nil {
  case process.receive(from, 60_000) {
    Ok(msg) -> {
      process.send(to, state.LoaderUpdated(msg))
      case msg {
        loader.LoaderUpdate(_, _, True) -> Nil
        loader.LoaderUpdate(_, _, False) -> relay_loop(from, to)
      }
    }
    Error(_) -> Nil
  }
}
