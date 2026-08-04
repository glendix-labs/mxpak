//// Installs configured packages for use by another build tool.
////
//// This entrypoint performs mxpak's package-resolution responsibility without
//// generating framework-specific source. Consumers such as Mendraw can invoke
//// it before running their own binding generator.

import gleam/dict
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import mxpak/error
import mxpak/lockfile
import mxpak/resolver

/// Runs the package installation entrypoint.
pub fn main() -> Nil {
  let project_root = case command_arguments() {
    [root, ..] -> root
    [] -> "."
  }
  case install(project_root) {
    Ok(count) ->
      io.println(
        "mxpak installed " <> string.inspect(count) <> " configured package(s).",
      )
    Error(reason) -> {
      io.println_error("mxpak install failed: " <> error.message(reason))
      halt(1)
    }
  }
}

fn install(project_root: String) -> Result(Int, error.Error) {
  use _ <- result.try(ensure_apps_started())
  use results <- result.try(resolver.resolve_all(project_root))
  use _ <- result.try(write_lockfile(project_root, results))
  Ok(list.length(results))
}

fn write_lockfile(
  project_root: String,
  results: List(resolver.ResolveResult),
) -> Result(Nil, error.Error) {
  let entries =
    list.fold(results, dict.new(), fn(accumulator, resolved) {
      dict.insert(
        accumulator,
        resolved.name,
        lockfile.LockEntry(
          version: resolved.version,
          hash: resolved.hash,
          content_id: resolved.content_id,
          s3_id: resolved.s3_id,
          kind: resolved.kind,
        ),
      )
    })
  lockfile.write(project_root, entries)
}

// -- FFI --

@external(erlang, "mxpak_ffi", "get_arguments")
fn command_arguments() -> List(String)

@external(erlang, "mxpak_ffi", "ensure_apps_started")
fn ensure_apps_started() -> Result(Nil, error.Error)

@external(erlang, "erlang", "halt")
fn halt(exit_status: Int) -> Nil
