//// Provides state operations for mxpak.
////

import gleam/dict
import gleam/erlang/process
import gleam/option
import mxpak/downloader
import mxpak/error
import mxpak/marketplace/loader
import mxpak/registry/content_api
import mxpak/registry/version_merger
import mxpak/registry/xas_parser

/// A typed `ViewMode` value used by the state capability.
pub type ViewMode {
  /// The `Browse` variant.
  Browse
  /// The `SelectVersion` variant.
  SelectVersion(
    name: String,
    versions: List(version_merger.MergedVersion),
    ver_cursor: Int,
    queue: List(#(Int, String)),
    xas_data: dict.Dict(Int, List(xas_parser.XasVersion)),
    content_id: Int,
  )
  /// The `InitialLoading` variant.
  InitialLoading(label: String)
  /// The `Working` variant.
  Working(label: String)
}

/// A typed `Model` value used by the state capability.
pub type Model {
  /// The `Model` variant.
  Model(
    pat: String,
    project_root: String,
    all_widgets: List(content_api.Widget),
    filtered: option.Option(List(content_api.Widget)),
    page_index: Int,
    cursor: Int,
    selected: List(Int),
    all_loaded: Bool,
    loader: option.Option(loader.LoaderHandle),
    offset: Int,
    search_query: String,
    view_mode: ViewMode,
    status_msg: option.Option(String),
    shore_subject: option.Option(process.Subject(Msg)),
    exit_subject: option.Option(process.Subject(Nil)),
  )
}

/// A typed `Msg` value used by the state capability.
pub type Msg {
  /// The `MoveCursor` variant.
  MoveCursor(Int)
  /// The `ChangePage` variant.
  ChangePage(Int)
  /// The `GoHome` variant.
  GoHome
  /// The `GoEnd` variant.
  GoEnd
  /// The `ToggleSelection` variant.
  ToggleSelection
  /// The `SearchChanged` variant.
  SearchChanged(String)
  /// The `StartDownload` variant.
  StartDownload
  /// The `ConfirmVersion` variant.
  ConfirmVersion
  /// The `GoBack` variant.
  GoBack
  /// The `Quit` variant.
  Quit
  /// The `LoaderUpdated` variant.
  LoaderUpdated(loader.LoaderMsg)
  /// The `SessionReady` variant.
  SessionReady(Result(Nil, error.Error))
  /// The `VersionInfoReady` variant.
  VersionInfoReady(
    widgets: List(#(Int, String)),
    result: Result(dict.Dict(Int, List(xas_parser.XasVersion)), error.Error),
  )
  /// The `ApiVersionsReady` variant.
  ApiVersionsReady(
    name: String,
    content_id: Int,
    queue: List(#(Int, String)),
    xas_data: dict.Dict(Int, List(xas_parser.XasVersion)),
    result: Result(List(content_api.ContentApiVersion), error.Error),
  )
  /// The `DownloadDone` variant.
  DownloadDone(
    name: String,
    queue: List(#(Int, String)),
    xas_data: dict.Dict(Int, List(xas_parser.XasVersion)),
    result: Result(downloader.DownloadResult, error.Error),
  )
}

/// The `display_size` constant used by the state capability.
pub const display_size = 10
