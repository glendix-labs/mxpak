//// Provides view operations for mxpak.
////

import gleam/int
import gleam/list
import gleam/option
import gleam/string
import mxpak/registry/content_api
import mxpak/registry/version_merger
import shore
import shore/style
import shore/ui

/// Represents whether the complete Marketplace result set is loaded.
pub type LoadState {
  /// More Marketplace pages may still be loading.
  Loading
  /// Every Marketplace page has been loaded.
  Loaded
}

/// Renders the Marketplace browse screen.
pub fn view_browse(
  items items: List(content_api.Widget),
  cursor cursor: Int,
  selected selected: List(Int),
  page page: Int,
  total_pages total_pages: String,
  status_msg status_msg: option.Option(String),
  load_state load_state: LoadState,
) -> shore.Node(msg) {
  let header = "  " <> bold(cyan("── mxpak Marketplace ──"))
  let widget_rows =
    list.index_map(items, fn(w, idx) {
      let is_cursor = idx == cursor
      let is_selected = list.contains(selected, idx)
      let marker = case is_cursor, is_selected {
        True, True -> green(" ▸●")
        True, False -> cyan(" ▸ ")
        False, True -> green("  ●")
        False, False -> "   "
      }
      let name = option.unwrap(w.name, "?")
      let version = case w.latest_version {
        option.Some(v) -> " v" <> v
        option.None -> ""
      }
      let publisher = case w.publisher {
        option.Some(p) -> dim(" — " <> p)
        option.None -> ""
      }
      let id_str = dim(" [" <> int.to_string(w.content_id) <> "]")
      let content = " " <> bold(name) <> version <> publisher <> id_str
      let line = case is_cursor {
        True -> marker <> white(content)
        False -> marker <> content
      }
      ui.text(line)
    })
  let page_info = dim("  페이지 " <> int.to_string(page) <> "/" <> total_pages)
  let loading_indicator = case load_state {
    Loaded -> ""
    Loading -> dim(" (로드 중...)")
  }
  let status_line = case status_msg {
    option.Some(msg) -> msg
    option.None -> ""
  }
  let help = dim("  Tab:검색  ↑↓:이동  ←→:페이지  Space:선택  Enter:다운로드  Ctrl+X:종료")
  ui.col(
    list.flatten([
      [ui.text(header), ui.br()],
      widget_rows,
      [
        ui.br(),
        ui.text(page_info <> loading_indicator),
        ui.text(status_line),
        ui.br(),
        ui.text(help),
      ],
    ]),
  )
}

/// Renders the version selection screen.
pub fn view_version(
  name name: String,
  versions versions: List(version_merger.MergedVersion),
  ver_cursor ver_cursor: Int,
  status_msg status_msg: option.Option(String),
) -> shore.Node(msg) {
  let header = "  " <> bold(cyan("── " <> name <> " — 버전 선택 ──"))
  let version_rows =
    list.index_map(versions, fn(v, idx) {
      let is_cursor = idx == ver_cursor
      let marker = case is_cursor {
        True -> cyan(" ▸ ")
        False -> "   "
      }
      let date = case v.publication_date {
        option.Some(d) -> string.slice(d, at_index: 0, length: 10)
        option.None -> "?"
      }
      let mendix = case v.min_mendix_version {
        option.Some(m) -> " (Mendix ≥" <> m <> ")"
        option.None -> ""
      }
      let type_label = case v.downloadable, v.react_ready {
        False, _ -> red(" [다운로드 불가]")
        True, option.Some(True) -> green(" [Pluggable]")
        True, option.Some(False) -> yellow(" [Classic]")
        True, option.None -> ""
      }
      let content =
        "v" <> v.version_number <> " (" <> date <> ")" <> mendix <> type_label
      let line = case is_cursor {
        True -> marker <> white(content)
        False -> marker <> content
      }
      ui.text(line)
    })
  let status_line = case status_msg {
    option.Some(msg) -> msg
    option.None -> ""
  }
  let help = dim("  ↑↓:이동  Enter:다운로드  Esc:목록으로  Ctrl+X:종료")
  ui.col(
    list.flatten([
      [ui.text(header), ui.br()],
      version_rows,
      [ui.br(), ui.text(status_line), ui.br(), ui.text(help)],
    ]),
  )
}

/// Renders a loading screen.
pub fn view_loading(label label: String) -> shore.Node(msg) {
  ui.col([
    ui.br(),
    ui.text_styled(
      "  -- mxpak Marketplace --",
      option.Some(style.Cyan),
      option.None,
    ),
    ui.br(),
    ui.text_styled("  " <> label, option.Some(style.Cyan), option.None),
    ui.br(),
    ui.text("  Ctrl+X: 종료"),
  ])
}

fn bold(text: String) -> String {
  "\u{001b}[1m" <> text <> "\u{001b}[0m"
}

fn dim(text: String) -> String {
  "\u{001b}[2m" <> text <> "\u{001b}[0m"
}

fn cyan(text: String) -> String {
  "\u{001b}[36m" <> text <> "\u{001b}[0m"
}

fn green(text: String) -> String {
  "\u{001b}[32m" <> text <> "\u{001b}[0m"
}

fn yellow(text: String) -> String {
  "\u{001b}[33m" <> text <> "\u{001b}[0m"
}

fn red(text: String) -> String {
  "\u{001b}[31m" <> text <> "\u{001b}[0m"
}

fn white(text: String) -> String {
  "\u{001b}[37;1m" <> text <> "\u{001b}[0m"
}
