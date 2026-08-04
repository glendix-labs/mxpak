//// Defines shared structured errors for the mxpak package.
////

/// Represents a package failure while preserving its business domain.
pub type Error {
  /// Browser automation failed.
  BrowserOperationFailed(message: String)
  /// Content-addressable cache work failed.
  CacheOperationFailed(message: String)
  /// Project configuration could not be read, parsed, or written.
  ConfigurationOperationFailed(message: String)
  /// A package download or extraction workflow failed.
  DownloadOperationFailed(message: String)
  /// A widget lockfile operation failed.
  LockfileOperationFailed(message: String)
  /// Marketplace registry communication or decoding failed.
  RegistryOperationFailed(message: String)
  /// Widget dependency resolution failed.
  ResolutionOperationFailed(message: String)
  /// Mendix browser-session management failed.
  SessionOperationFailed(message: String)
  /// Workspace discovery, scanning, or status calculation failed.
  WorkspaceOperationFailed(message: String)
  /// An Erlang runtime application required by mxpak could not start.
  RuntimeApplicationCouldNotStart(application: String, reason: String)
  /// An MPK archive could not be extracted.
  ArchiveCouldNotBeExtracted(reason: String)
  /// A hard link could not be created.
  HardLinkCouldNotBeCreated(
    existing_path: String,
    new_path: String,
    reason: String,
  )
  /// Filesystem metadata could not be read.
  FileMetadataCouldNotBeRead(path: String, reason: String)
  /// A directory could not be listed recursively.
  DirectoryCouldNotBeListed(path: String, reason: String)
}

/// Represents a lookup that found no matching value.
pub type MissingValue {
  /// No matching value was available.
  MissingValue
}

/// Creates a browser-domain error.
pub fn browser(message message: String) -> Error {
  BrowserOperationFailed(message: message)
}

/// Creates a cache-domain error.
pub fn cache(message message: String) -> Error {
  CacheOperationFailed(message: message)
}

/// Creates a configuration-domain error.
pub fn configuration(message message: String) -> Error {
  ConfigurationOperationFailed(message: message)
}

/// Creates a download-domain error.
pub fn download(message message: String) -> Error {
  DownloadOperationFailed(message: message)
}

/// Creates a lockfile-domain error.
pub fn lockfile(message message: String) -> Error {
  LockfileOperationFailed(message: message)
}

/// Creates a registry-domain error.
pub fn registry(message message: String) -> Error {
  RegistryOperationFailed(message: message)
}

/// Creates a resolution-domain error.
pub fn resolution(message message: String) -> Error {
  ResolutionOperationFailed(message: message)
}

/// Creates a session-domain error.
pub fn session(message message: String) -> Error {
  SessionOperationFailed(message: message)
}

/// Creates a workspace-domain error.
pub fn workspace(message message: String) -> Error {
  WorkspaceOperationFailed(message: message)
}

/// Returns the human-readable error explanation.
pub fn message(from error: Error) -> String {
  case error {
    BrowserOperationFailed(message)
    | CacheOperationFailed(message)
    | ConfigurationOperationFailed(message)
    | DownloadOperationFailed(message)
    | LockfileOperationFailed(message)
    | RegistryOperationFailed(message)
    | ResolutionOperationFailed(message)
    | SessionOperationFailed(message)
    | WorkspaceOperationFailed(message)
    | ArchiveCouldNotBeExtracted(message) -> message
    RuntimeApplicationCouldNotStart(application, reason) ->
      "runtime application " <> application <> " could not start: " <> reason
    HardLinkCouldNotBeCreated(existing_path, new_path, reason) ->
      "create hard link failed for "
      <> existing_path
      <> " -> "
      <> new_path
      <> ": "
      <> reason
    FileMetadataCouldNotBeRead(path, reason) ->
      "read file metadata failed for " <> path <> ": " <> reason
    DirectoryCouldNotBeListed(path, reason) ->
      "list directory recursively failed for " <> path <> ": " <> reason
  }
}
