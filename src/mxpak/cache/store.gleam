//// Provides store operations for mxpak.
////

// CAS (Content-Addressable Storage) — ~/.mxpak/store/{sha256}/
import gleam/list
import gleam/result
import gleam/string
import mxpak/cache/integrity
import mxpak/error
import simplifile

/// Returns the root directory of the global cache.
pub fn cache_root() -> String {
  case get_home_dir() {
    Ok(home) -> home <> "/.mxpak/store"
    Error(_) -> ".mxpak/store"
  }
}

/// Returns the cache directory for a hash.
pub fn cache_path(hash hash: String) -> String {
  cache_root() <> "/" <> hash
}

/// Reports whether the requested cache entry exists.
pub fn has(hash hash: String) -> Result(Bool, error.Error) {
  let path = cache_path(hash)
  simplifile.is_directory(path)
  |> result.map_error(fn(reason) {
    error.cache("캐시 경로 확인 실패: " <> path <> ": " <> string.inspect(reason))
  })
}

/// Stores an MPK and its entries under their content hash.
pub fn put(
  data data: BitArray,
  entries entries: List(#(String, BitArray)),
) -> Result(#(String, String), error.Error) {
  let hash = integrity.sha256(data)
  let dir = cache_path(hash)
  use cached <- result.try(has(hash))
  case cached {
    True -> Ok(#(dir, hash))
    False -> {
      use _ <- result.try(
        simplifile.create_directory_all(dir)
        |> result.map_error(fn(_) { error.cache("캐시 디렉토리 생성 실패: " <> dir) }),
      )
      use _ <- result.try(
        simplifile.write_bits(dir <> "/original.mpk", data)
        |> result.map_error(fn(_) { error.cache("원본 .mpk 캐시 저장 실패") }),
      )
      use _ <- result.try(
        list.try_each(entries, fn(entry) {
          let #(name, content) = entry
          let out_path = dir <> "/" <> name
          let out_dir = dirname(out_path)
          use _ <- result.try(
            simplifile.create_directory_all(out_dir)
            |> result.map_error(fn(_) { error.cache("디렉토리 생성 실패: " <> out_dir) }),
          )
          simplifile.write_bits(out_path, content)
          |> result.map_error(fn(_) { error.cache("캐시 파일 쓰기 실패: " <> out_path) })
        }),
      )
      Ok(#(dir, hash))
    }
  }
}

/// Links cached entries into a project.
pub fn link_to_project(
  hash hash: String,
  target_dir target_dir: String,
) -> Result(Nil, error.Error) {
  let src = cache_path(hash)
  use cached <- result.try(has(hash))
  case cached {
    False -> Error(error.cache("캐시에 해당 해시가 없습니다: " <> hash))
    True -> {
      use _ <- result.try(
        simplifile.create_directory_all(target_dir)
        |> result.map_error(fn(_) { error.cache("대상 디렉토리 생성 실패") }),
      )
      link_dir(src, target_dir)
    }
  }
}

/// Removes all cached package data.
pub fn clean() -> Result(Nil, error.Error) {
  let root = cache_root()
  case simplifile.is_directory(root) {
    Ok(True) ->
      simplifile.delete(root)
      |> result.map_error(fn(_) { error.cache("캐시 삭제 실패") })
    Ok(False) -> Ok(Nil)
    Error(reason) ->
      Error(error.cache(
        "캐시 경로 확인 실패: " <> root <> ": " <> string.inspect(reason),
      ))
  }
}

/// Restores the original MPK to the requested path.
pub fn restore_mpk(
  hash hash: String,
  target_path target_path: String,
) -> Result(Nil, error.Error) {
  let src = cache_path(hash) <> "/original.mpk"
  case simplifile.is_file(src) {
    Ok(True) -> link_file(src, target_path)
    Ok(False) -> Error(error.cache("캐시에 original.mpk가 없습니다: " <> hash))
    Error(reason) ->
      Error(error.cache(
        "캐시 파일 확인 실패: " <> src <> ": " <> string.inspect(reason),
      ))
  }
}

/// Stores a file under its content hash.
pub fn put_file(
  data data: BitArray,
  filename filename: String,
) -> Result(#(String, String), error.Error) {
  let hash = integrity.sha256(data)
  let dir = cache_path(hash)
  use cached <- result.try(has(hash))
  case cached {
    True -> Ok(#(dir, hash))
    False -> {
      use _ <- result.try(
        simplifile.create_directory_all(dir)
        |> result.map_error(fn(_) { error.cache("캐시 디렉토리 생성 실패: " <> dir) }),
      )
      use _ <- result.try(
        simplifile.write_bits(dir <> "/" <> filename, data)
        |> result.map_error(fn(_) { error.cache("파일 캐시 저장 실패: " <> filename) }),
      )
      Ok(#(dir, hash))
    }
  }
}

/// Restores the file.
pub fn restore_file(
  hash hash: String,
  filename filename: String,
  target_path target_path: String,
) -> Result(Nil, error.Error) {
  let src = cache_path(hash) <> "/" <> filename
  case simplifile.is_file(src) {
    Ok(True) -> link_file(src, target_path)
    Ok(False) -> Error(error.cache("캐시에 파일이 없습니다: " <> hash <> "/" <> filename))
    Error(reason) ->
      Error(error.cache(
        "캐시 파일 확인 실패: " <> src <> ": " <> string.inspect(reason),
      ))
  }
}

/// Creates a hard link through the Erlang filesystem boundary.
@internal
pub fn create_hard_link(
  from existing_path: String,
  to new_path: String,
) -> Result(Nil, error.Error) {
  make_hard_link(existing_path, new_path)
}

fn dirname(path: String) -> String {
  let parts = string.split(path, "/")
  case list.length(parts) > 1 {
    True ->
      list.take(parts, list.length(parts) - 1)
      |> string.join("/")
    False -> "."
  }
}

/// Links or copies a cached file to its destination.
fn link_file(src: String, dest: String) -> Result(Nil, error.Error) {
  use _ <- result.try(case simplifile.delete(dest) {
    Ok(Nil) | Error(simplifile.Enoent) -> Ok(Nil)
    Error(_) -> Error(error.cache("기존 대상 파일 삭제 실패: " <> dest))
  })
  case create_hard_link(src, dest) {
    Ok(_) -> Ok(Nil)
    Error(_) ->
      simplifile.copy_file(src, dest)
      |> result.map_error(fn(_) { error.cache("파일 링크/복사 실패: " <> dest) })
      |> result.map(fn(_) { Nil })
  }
}

fn link_dir(src: String, dest: String) -> Result(Nil, error.Error) {
  use files <- result.try(
    simplifile.read_directory(src)
    |> result.map_error(fn(_) { error.cache("디렉토리 읽기 실패: " <> src) }),
  )
  list.try_each(files, fn(file) {
    case file == "original.mpk" {
      True -> Ok(Nil)
      False -> link_entry(src <> "/" <> file, dest <> "/" <> file)
    }
  })
}

fn link_entry(src_path: String, dest_path: String) -> Result(Nil, error.Error) {
  case simplifile.is_directory(src_path) {
    Ok(True) -> {
      use _ <- result.try(
        simplifile.create_directory_all(dest_path)
        |> result.map_error(fn(_) { error.cache("디렉토리 생성 실패") }),
      )
      link_dir(src_path, dest_path)
    }
    Ok(False) -> link_file(src_path, dest_path)
    Error(reason) ->
      Error(error.cache(
        "캐시 경로 확인 실패: " <> src_path <> ": " <> string.inspect(reason),
      ))
  }
}

// -- FFI --

@external(erlang, "mxpak_ffi", "make_hard_link")
fn make_hard_link(
  existing_path: String,
  new_path: String,
) -> Result(Nil, error.Error)

@external(erlang, "mxpak_ffi", "get_home_dir")
fn get_home_dir() -> Result(String, error.MissingValue)
