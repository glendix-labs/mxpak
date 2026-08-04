//// Provides status operations for mxpak.
////

import gleam/dict
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import mxpak/cache/integrity
import mxpak/error
import mxpak/workspace
import mxpak/workspace/file_boundary
import simplifile

/// A typed `ProjectStats` value used by the status capability.
pub type ProjectStats {
  /// The `ProjectStats` variant.
  ProjectStats(name: String, total_files: Int, total_bytes: Int)
}

/// A typed `WorkspaceStatus` value used by the status capability.
pub type WorkspaceStatus {
  /// The `WorkspaceStatus` variant.
  WorkspaceStatus(
    projects: List(ProjectStats),
    total_files: Int,
    unique_hashes: Int,
    potential_savings: Int,
  )
}

/// Calculates deduplication statistics for a workspace.
pub fn check(
  config config: workspace.WorkspaceConfig,
) -> Result(WorkspaceStatus, error.Error) {
  use projects <- result.try(workspace.discover_projects(config.root))
  use project_stats <- result.try(
    list.try_map(projects, fn(project) { count_project(project, config) }),
  )
  use hash_counts <- result.try(count_hashes(projects, config))
  let total = list.fold(project_stats, 0, fn(acc, ps) { acc + ps.total_files })
  let unique = dict.size(hash_counts)
  let potential =
    dict.fold(hash_counts, 0, fn(acc, _hash, info) {
      let #(count, size) = info
      case count > 1 {
        True -> acc + { { count - 1 } * size }
        False -> acc
      }
    })
  Ok(WorkspaceStatus(
    projects: project_stats,
    total_files: total,
    unique_hashes: unique,
    potential_savings: potential,
  ))
}

/// Formats a value for display.
pub fn format(status status: WorkspaceStatus) -> String {
  let header = "워크스페이스 상태\n"
  let divider = string.repeat("─", 40) <> "\n"
  let project_lines =
    list.map(status.projects, fn(ps) {
      "  "
      <> ps.name
      <> ": "
      <> int.to_string(ps.total_files)
      <> "개 파일, "
      <> format_bytes(ps.total_bytes)
    })
    |> string.join("\n")
  let summary =
    "\n"
    <> divider
    <> "전체 파일: "
    <> int.to_string(status.total_files)
    <> "\n고유 해시: "
    <> int.to_string(status.unique_hashes)
    <> "\n중복 파일: "
    <> int.to_string(status.total_files - status.unique_hashes)
    <> "\n절감 가능: "
    <> format_bytes(status.potential_savings)
  header <> divider <> project_lines <> summary
}

fn count_project(
  project_root: String,
  config: workspace.WorkspaceConfig,
) -> Result(ProjectStats, error.Error) {
  use files <- result.try(
    file_boundary.list_recursively(project_root, config.exclude_dirs)
    |> result.map_error(fn(_) { error.workspace("디렉토리 읽기 실패") }),
  )
  let matching =
    list.filter(files, fn(path) { matches_include(path, config.include) })
  use total_bytes <- result.try(
    list.try_fold(matching, 0, fn(acc, path) {
      use metadata <- result.try(file_boundary.inspect(path))
      let file_boundary.FileMetadata(size_bytes, _inode) = metadata
      Ok(acc + size_bytes)
    }),
  )
  let name = basename(project_root)
  Ok(ProjectStats(
    name: name,
    total_files: list.length(matching),
    total_bytes: total_bytes,
  ))
}

fn count_hashes(
  projects: List(String),
  config: workspace.WorkspaceConfig,
) -> Result(dict.Dict(String, #(Int, Int)), error.Error) {
  list.try_fold(projects, dict.new(), fn(acc, project) {
    use files <- result.try(
      file_boundary.list_recursively(project, config.exclude_dirs)
      |> result.map_error(fn(_) { error.workspace("디렉토리 읽기 실패") }),
    )
    let matching = list.filter(files, fn(path) { matches_scan(path, config) })
    list.try_fold(matching, acc, fn(hash_map, path) {
      use metadata <- result.try(file_boundary.inspect(path))
      let file_boundary.FileMetadata(size_bytes, _inode) = metadata
      use data <- result.try(
        simplifile.read_bits(path)
        |> result.map_error(fn(reason) {
          error.workspace(
            "파일 읽기 실패: " <> path <> ": " <> string.inspect(reason),
          )
        }),
      )
      let hash = integrity.sha256(data)
      let current = case dict.get(hash_map, hash) {
        Ok(#(count, existing_size)) -> #(count + 1, existing_size)
        Error(_) -> #(1, size_bytes)
      }
      Ok(dict.insert(hash_map, hash, current))
    })
  })
}

fn matches_scan(path: String, config: workspace.WorkspaceConfig) -> Bool {
  matches_include(path, config.include)
  || matches_include_dir(path, config.include_dirs)
}

fn matches_include(path: String, patterns: List(String)) -> Bool {
  list.any(patterns, fn(pattern) {
    case string.starts_with(pattern, "*.") {
      True -> {
        let ext = string.drop_start(pattern, 1)
        string.ends_with(path, ext)
      }
      False -> string.ends_with(path, pattern)
    }
  })
}

fn matches_include_dir(path: String, dirs: List(String)) -> Bool {
  let normalized = string.replace(path, "\\", "/")
  list.any(dirs, fn(dir) { string.contains(normalized, "/" <> dir <> "/") })
}

fn format_bytes(bytes: Int) -> String {
  case bytes {
    b if b >= 1_048_576 -> {
      let mb = b / 1_048_576
      let remainder = { b % 1_048_576 } * 10 / 1_048_576
      int.to_string(mb) <> "." <> int.to_string(remainder) <> " MB"
    }
    b if b >= 1024 -> {
      let kb = b / 1024
      int.to_string(kb) <> " KB"
    }
    b -> int.to_string(b) <> " B"
  }
}

fn basename(path: String) -> String {
  let normalized = string.replace(path, "\\", "/")
  case string.split(normalized, "/") |> list.last {
    Ok(name) -> name
    Error(_) -> path
  }
}
