//// Discovers Mendix projects and reads workspace configuration.
////

import gleam/list
import gleam/result
import gleam/string
import mxpak/error
import simplifile
import tom

/// A typed `WorkspaceConfig` value used by the workspace capability.
pub type WorkspaceConfig {
  /// The `WorkspaceConfig` variant.
  WorkspaceConfig(
    root: String,
    include: List(String),
    include_dirs: List(String),
    exclude_dirs: List(String),
  )
}

/// Reads the config.
pub fn read_config(root root: String) -> Result(WorkspaceConfig, error.Error) {
  let config_path = root <> "/.mxpak-workspace.toml"
  case simplifile.is_file(config_path) {
    Ok(True) -> parse_config(root, config_path)
    _ -> Ok(default_config(root))
  }
}

/// Reports whether a directory is a Mendix project.
pub fn is_mendix_project_dir(root root: String) -> Result(Bool, error.Error) {
  simplifile.read_directory(root)
  |> result.map(fn(entries) {
    list.any(entries, fn(name) { string.ends_with(name, ".mpr") })
  })
  |> result.map_error(fn(reason) {
    error.workspace(
      "프로젝트 디렉터리 확인 실패: " <> root <> ": " <> string.inspect(reason),
    )
  })
}

/// Discovers Mendix projects below a workspace root.
pub fn discover_projects(
  root root: String,
) -> Result(List(String), error.Error) {
  use root_is_project <- result.try(is_mendix_project_dir(root))
  case root_is_project {
    True -> Ok([root])
    False -> {
      use entries <- result.try(
        simplifile.read_directory(root)
        |> result.map_error(fn(_) { error.workspace("디렉토리 읽기 실패: " <> root) }),
      )
      use projects <- result.try(
        list.try_fold(entries, [], fn(projects, name) {
          let path = root <> "/" <> name
          case string.starts_with(name, ".") {
            True -> Ok(projects)
            False ->
              case simplifile.is_directory(path) {
                Ok(True) -> {
                  use is_project <- result.try(is_mendix_project_dir(path))
                  case is_project {
                    True -> Ok([path, ..projects])
                    False -> Ok(projects)
                  }
                }
                Ok(False) -> Ok(projects)
                Error(reason) ->
                  Error(error.workspace(
                    "하위 프로젝트 경로 확인 실패: "
                    <> path
                    <> ": "
                    <> string.inspect(reason),
                  ))
              }
          }
        }),
      )
      Ok(list.reverse(projects))
    }
  }
}

fn default_config(root: String) -> WorkspaceConfig {
  WorkspaceConfig(
    root: root,
    include: ["*.mpk", "*.jar"],
    include_dirs: ["themesource"],
    exclude_dirs: [
      ".git", ".svn", ".mendix-cache", "theme-cache", "deployment",
      "mprcontents", "releases", "resources", "javascriptsource", "javasource",
      "mlsource", "modules", "theme", "node_modules",
    ],
  )
}

fn parse_config(
  root: String,
  config_path: String,
) -> Result(WorkspaceConfig, error.Error) {
  use content <- result.try(
    simplifile.read(config_path)
    |> result.map_error(fn(_) {
      error.workspace("설정 파일 읽기 실패: " <> config_path)
    }),
  )
  use parsed <- result.try(
    tom.parse(content)
    |> result.map_error(fn(_) { error.workspace("설정 파일 파싱 실패") }),
  )
  let include = case tom.get_array(parsed, ["scan", "include"]) {
    Ok(arr) ->
      list.filter_map(arr, fn(v) {
        case v {
          tom.String(s) -> Ok(s)
          tom.Int(_)
          | tom.Float(_)
          | tom.Infinity(_)
          | tom.Nan(_)
          | tom.Bool(_)
          | tom.Date(_)
          | tom.Time(_)
          | tom.DateTime(..)
          | tom.Array(_)
          | tom.ArrayOfTables(_)
          | tom.Table(_)
          | tom.InlineTable(_) -> Error(Nil)
        }
      })
    Error(_) -> default_config(root).include
  }
  let include_dirs = case tom.get_array(parsed, ["scan", "include_dirs"]) {
    Ok(arr) ->
      list.filter_map(arr, fn(v) {
        case v {
          tom.String(s) -> Ok(s)
          tom.Int(_)
          | tom.Float(_)
          | tom.Infinity(_)
          | tom.Nan(_)
          | tom.Bool(_)
          | tom.Date(_)
          | tom.Time(_)
          | tom.DateTime(..)
          | tom.Array(_)
          | tom.ArrayOfTables(_)
          | tom.Table(_)
          | tom.InlineTable(_) -> Error(Nil)
        }
      })
    Error(_) -> default_config(root).include_dirs
  }
  let exclude_dirs = case tom.get_array(parsed, ["scan", "exclude_dirs"]) {
    Ok(arr) ->
      list.filter_map(arr, fn(v) {
        case v {
          tom.String(s) -> Ok(s)
          tom.Int(_)
          | tom.Float(_)
          | tom.Infinity(_)
          | tom.Nan(_)
          | tom.Bool(_)
          | tom.Date(_)
          | tom.Time(_)
          | tom.DateTime(..)
          | tom.Array(_)
          | tom.ArrayOfTables(_)
          | tom.Table(_)
          | tom.InlineTable(_) -> Error(Nil)
        }
      })
    Error(_) -> default_config(root).exclude_dirs
  }
  Ok(WorkspaceConfig(
    root: root,
    include: include,
    include_dirs: include_dirs,
    exclude_dirs: exclude_dirs,
  ))
}
