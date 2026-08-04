//// Provides scanner operations for mxpak.
////

import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import mxpak/cache/integrity
import mxpak/cache/store
import mxpak/error
import mxpak/workspace
import mxpak/workspace/file_boundary
import simplifile

/// A typed `ScanResult` value used by the scanner capability.
pub type ScanResult {
  /// The `ScanResult` variant.
  ScanResult(
    total_files: Int,
    unique_hashes: Int,
    duplicate_groups: Int,
    linked_files: Int,
    saved_bytes: Int,
  )
}

/// Scans workspace files and replaces duplicates with cached links.
pub fn scan_and_dedup(
  config config: workspace.WorkspaceConfig,
) -> Result(ScanResult, error.Error) {
  use projects <- result.try(workspace.discover_projects(config.root))
  case projects {
    [] -> Ok(ScanResult(0, 0, 0, 0, 0))
    _ -> {
      use all_files <- result.try(collect_files(projects, config))
      use hash_groups <- result.try(group_by_hash(all_files))
      let dup_groups =
        dict.filter(hash_groups, fn(_hash, files) { list.length(files) > 1 })
      use dedup_result <- result.try(dedup_groups(dup_groups))
      let total = list.length(all_files)
      let unique = dict.size(hash_groups)
      let groups = dict.size(dup_groups)
      Ok(ScanResult(
        total_files: total,
        unique_hashes: unique,
        duplicate_groups: groups,
        linked_files: dedup_result.linked,
        saved_bytes: dedup_result.saved,
      ))
    }
  }
}

/// A typed `FileEntry` value used by the scanner capability.
type FileEntry {
  FileEntry(path: String, size: Int)
}

type DedupStats {
  DedupStats(linked: Int, saved: Int)
}

fn collect_files(
  projects: List(String),
  config: workspace.WorkspaceConfig,
) -> Result(List(FileEntry), error.Error) {
  use nested <- result.try(
    list.try_map(projects, fn(project) {
      collect_project_files(project, config)
    }),
  )
  Ok(list.flatten(nested))
}

fn collect_project_files(
  project_root: String,
  config: workspace.WorkspaceConfig,
) -> Result(List(FileEntry), error.Error) {
  use file_paths <- result.try(
    file_boundary.list_recursively(project_root, config.exclude_dirs)
    |> result.map_error(fn(reason) {
      error.workspace(
        "디렉토리 스캔 실패: " <> project_root <> ": " <> error.message(reason),
      )
    }),
  )
  use reversed <- result.try(
    list.try_fold(file_paths, [], fn(entries, path) {
      case matches_scan(path, config) {
        False -> Ok(entries)
        True -> {
          use metadata <- result.try(file_boundary.inspect(path))
          let file_boundary.FileMetadata(size_bytes, _inode) = metadata
          Ok([FileEntry(path, size_bytes), ..entries])
        }
      }
    }),
  )
  Ok(list.reverse(reversed))
}

/// Reports whether a path matches the configured scan rules.
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

fn group_by_hash(
  files: List(FileEntry),
) -> Result(dict.Dict(String, List(FileEntry)), error.Error) {
  list.try_fold(files, dict.new(), fn(acc, entry) {
    use data <- result.try(
      simplifile.read_bits(entry.path)
      |> result.map_error(fn(_) { error.workspace("파일 읽기 실패: " <> entry.path) }),
    )
    let hash = integrity.sha256(data)
    let current = case dict.get(acc, hash) {
      Ok(existing) -> [entry, ..existing]
      Error(_) -> [entry]
    }
    Ok(dict.insert(acc, hash, current))
  })
}

fn dedup_groups(
  groups: dict.Dict(String, List(FileEntry)),
) -> Result(DedupStats, error.Error) {
  dict.fold(groups, Ok(DedupStats(0, 0)), fn(acc_result, hash, files) {
    use acc <- result.try(acc_result)
    use stats <- result.try(dedup_single_group(hash, files))
    Ok(DedupStats(
      linked: acc.linked + stats.linked,
      saved: acc.saved + stats.saved,
    ))
  })
}

fn dedup_single_group(
  hash: String,
  files: List(FileEntry),
) -> Result(DedupStats, error.Error) {
  case files {
    [] | [_] -> Ok(DedupStats(0, 0))
    [first, ..rest] -> {
      use cached <- result.try(store.has(hash))
      use _ <- result.try(case cached {
        False -> {
          use data <- result.try(
            simplifile.read_bits(first.path)
            |> result.map_error(fn(_) {
              error.workspace("파일 읽기 실패: " <> first.path)
            }),
          )
          let filename = basename(first.path)
          store.put_file(data, filename)
          |> result.map(fn(_) { Nil })
        }
        True -> Ok(Nil)
      })
      let all_files = [first, ..rest]
      use linked_count <- result.try(
        list.try_fold(all_files, 0, fn(count, entry) {
          let filename = basename(entry.path)
          use _ <- result.try(
            store.restore_file(hash, filename, entry.path)
            |> result.map_error(fn(reason) {
              error.workspace(
                "중복 파일 복원 실패: " <> entry.path <> ": " <> error.message(reason),
              )
            }),
          )
          Ok(count + 1)
        }),
      )
      let saved = { list.length(all_files) - 1 } * first.size
      Ok(DedupStats(linked: linked_count, saved: saved))
    }
  }
}

fn basename(path: String) -> String {
  let normalized = string.replace(path, "\\", "/")
  case string.split(normalized, "/") |> list.last {
    Ok(name) -> name
    Error(_) -> path
  }
}
