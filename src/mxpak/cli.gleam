//// Provides cli operations for mxpak.
////

import gleam/io

/// A typed `VersionArg` value used by the cli capability.
pub type VersionArg {
  /// The `VersionSpecified` variant.
  VersionSpecified(String)
  /// The `VersionLatest` variant.
  VersionLatest
}

/// A typed `Command` value used by the cli capability.
pub type Command {
  /// The `Install` variant.
  Install(project_root: String)
  /// The `Marketplace` variant.
  Marketplace(project_root: String)
  /// The `Add` variant.
  Add(name: String, version: VersionArg)
  /// The `Remove` variant.
  Remove(name: String)
  /// The `Update` variant.
  Update(name: String)
  /// The `Outdated` variant.
  Outdated(project_root: String)
  /// The `List` variant.
  List(project_root: String)
  /// The `Info` variant.
  Info(name: String)
  /// The `Audit` variant.
  Audit(project_root: String)
  /// The `CacheClean` variant.
  CacheClean
  /// The `Scan` variant.
  Scan(path: String)
  /// The `Status` variant.
  Status(path: String)
  /// The `Version` variant.
  Version
  /// The `Help` variant.
  Help
  /// The `Unknown` variant.
  Unknown(cmd: String)
}

/// Parses the supplied value.
pub fn parse(args args: List(String)) -> Command {
  case args {
    [] -> Help
    ["--version"] | ["-v"] -> Version
    ["--help"] | ["-h"] -> Help
    ["install"] -> Install(".")
    ["install", root] -> Install(root)
    ["marketplace"] -> Marketplace(".")
    ["marketplace", root] -> Marketplace(root)
    ["add", name] -> Add(name, VersionLatest)
    ["add", name, "--version", v] -> Add(name, VersionSpecified(v))
    ["remove", name] -> Remove(name)
    ["update"] -> Update("")
    ["update", name] -> Update(name)
    ["outdated"] -> Outdated(".")
    ["outdated", root] -> Outdated(root)
    ["list"] -> List(".")
    ["list", root] -> List(root)
    ["info", name] -> Info(name)
    ["audit"] -> Audit(".")
    ["audit", root] -> Audit(root)
    ["cache", "clean"] -> CacheClean
    ["scan"] -> Scan("")
    ["scan", path] -> Scan(path)
    ["status"] -> Status("")
    ["status", path] -> Status(path)
    [cmd, ..] -> Unknown(cmd)
  }
}

/// Prints command-line usage information.
pub fn print_help() -> Nil {
  io.println(
    "mxpak — Mendix 위젯/공통파일 패키지매니저
사용법: mxp <command> [options]
명령어:
  install [project_root]           위젯 설치 (락파일 우선, 없으면 해결)
  add <name> [--version <v>]       위젯 추가
  remove <name>                    위젯 제거
  update [name]                    위젯 업데이트
  marketplace [project_root]       Marketplace TUI 브라우저
  outdated [project_root]          업데이트 가능한 위젯 목록
  list [project_root]              설치된 위젯 목록
  info <name>                      위젯 상세 정보
  audit [project_root]             무결성 검증 (SHA-256)
  cache clean                      글로벌 캐시 정리
중복제거 (단일 Mendix 프로젝트 또는 여러 프로젝트 부모 디렉토리 모두 가능):
  scan [path]                      *.mpk + *.jar + themesource/** 중복제거 (CAS + 하드 링크)
  status [path]                    중복제거 상태 + 절감량 표시
옵션:
  --version, -v                    버전 출력
  --help, -h                       도움말",
  )
}
