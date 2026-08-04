//// Models the runtime kind of a Mendix widget package.
////

/// Represents whether a widget uses the classic or pluggable runtime.
pub type Kind {
  /// A modern pluggable widget containing JavaScript modules.
  Pluggable
  /// A classic widget containing legacy JavaScript or HTML assets.
  Classic
}

/// Reports whether a widget uses the classic runtime.
pub fn is_classic(kind kind: Kind) -> Bool {
  case kind {
    Classic -> True
    Pluggable -> False
  }
}
