import std/[unittest, options]
import ../src/sources/utils

suite "Utils":
    test "Convert some `Option[seq[cstring]]` to `Option[seq[string]]`":
      let
        cstringSeq: Option[seq[cstring]] = some @[cstring "test!", cstring "test?"]
        stringSeq: Option[seq[string]] = some @["test!", "test?"]
      check to(cstringSeq) == stringSeq

    test "Convert none `Option[seq[cstring]]` to `Option[seq[string]]`":
      let
        cstringSeq: Option[seq[cstring]] = none seq[cstring]
        stringSeq: Option[seq[string]] = none seq[string]
      check to(cstringSeq) == stringSeq

    test "Convert some `Option[seq[string]]` to `Option[seq[cstring]]`":
      let
        stringSeq: Option[seq[string]] = some @["test!", "test?"]
        cstringSeq: Option[seq[cstring]] = some @[cstring "test!", cstring "test?"]
      check to(stringSeq) == cstringSeq

    test "Convert none `Option[seq[string]]` to `Option[seq[cstring]]`":
      let
        stringSeq: Option[seq[string]] = none seq[string]
        cstringSeq: Option[seq[cstring]] = none seq[cstring]
      check to(stringSeq) == cstringSeq

    test "Convert some `Option[string]` to `Option[cstring]`":
      let
        str: Option[string] = some "test!"
        cstr: Option[cstring] = some cstring "test!"
      check to(str) == cstr

    test "Convert none `Option[string]` to `Option[cstring]`":
      let
        str: Option[string] = none string
        cstr: Option[cstring] = none cstring
      check to(str) == cstr

    test "Convert some `Option[cstring]` to `Option[string]`":
      let
        cstr: Option[cstring] = some cstring "test!"
        str: Option[string] = some "test!"
      check to(cstr) == str

    test "Convert none `Option[cstring]` to `Option[string]`":
      let
        cstr: Option[cstring] = none cstring
        str: Option[string] = none string
      check to(cstr) == str
