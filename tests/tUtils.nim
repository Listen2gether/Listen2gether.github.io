import std/[unittest, options]
import ../src/sources/utils

suite "Utils":
    setup:
      let
        someCstrSeq: Option[seq[cstring]] = some @[cstring "test!", cstring "test?"]
        noneCstrSeq: Option[seq[cstring]] = none seq[cstring]
        someCstr: Option[cstring] = some cstring ""
        noneCstr: Option[cstring] = none cstring

        someStrSeq: Option[seq[string]] = some @["test!", "test?"]
        noneStrSeq: Option[seq[string]] = none seq[string]
        someStr: Option[string] = some ""
        noneStr: Option[string] = none string

    test "Convert some `Option[seq[cstring]]` to `Option[seq[string]]`":
      check to(someCstrSeq) == someStrSeq

    test "Convert none `Option[seq[cstring]]` to `Option[seq[string]]`":
      check to(noneCstrSeq) == noneStrSeq

    test "Convert some `Option[seq[string]]` to `Option[seq[cstring]]`":
      check to(someStrSeq) == someCstrSeq

    test "Convert none `Option[seq[string]]` to `Option[seq[cstring]]`":
      check to(noneStrSeq) == noneCstrSeq

    test "Convert some `Option[string]` to `Option[cstring]`":
      check to(someStr) == someCstr

    test "Convert none `Option[string]` to `Option[cstring]`":
      check to(noneStr) == noneCstr

    test "Convert some `Option[cstring]` to `Option[string]`":
      check to(someCstr) == someStr

    test "Convert none `Option[cstring]` to `Option[string]`":
      check to(noneCstr) == noneStr
