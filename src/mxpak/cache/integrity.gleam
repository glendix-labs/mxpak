//// Provides integrity operations for mxpak.
////

import gleam/crypto

/// Computes the SHA-256 digest of the supplied bytes.
pub fn sha256(data data: BitArray) -> String {
  crypto.hash(crypto.Sha256, data)
  |> hex_encode
}

/// Checks the supplied bytes against an expected content hash.
pub fn verify(
  data data: BitArray,
  expected_hash expected_hash: String,
) -> Bool {
  sha256(data) == expected_hash
}

fn hex_encode(bytes: BitArray) -> String {
  do_hex_encode(bytes, "")
}

fn do_hex_encode(bytes: BitArray, acc: String) -> String {
  case bytes {
    <<byte:int, rest:bits>> -> {
      let hi = hex_char(byte / 16)
      let lo = hex_char(byte % 16)
      do_hex_encode(rest, acc <> hi <> lo)
    }
    _ -> acc
  }
}

fn hex_char(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    15 -> "f"
    _ -> "?"
  }
}
