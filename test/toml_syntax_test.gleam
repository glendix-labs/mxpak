//// Tests TOML syntax encoding for mxpak.
////

import gleeunit/should
import mxpak/toml_syntax

/// Verifies basic string escapes.
pub fn quote_basic_string_test() -> Nil {
  toml_syntax.quote_basic_string("a\"b\\c\nd\te")
  |> should.equal("\"a\\\"b\\\\c\\nd\\te\"")
  Nil
}

/// Verifies bare keys stay bare and hostile keys become quoted.
pub fn quote_key_test() -> Nil {
  toml_syntax.quote_key("Data-Grid_2")
  |> should.equal("Data-Grid_2")
  toml_syntax.quote_key("Data Grid")
  |> should.equal("\"Data Grid\"")
  toml_syntax.quote_key("quote\"key")
  |> should.equal("\"quote\\\"key\"")
  Nil
}
