when defined(js):
  import std/jsconsole
import
  std/[options, strutils],
  pkg/union,
  pkg/union/uniontraits

proc unionToInt*[T: Union](val: T): Option[int] =
  ## Convert `union(Option[string] | Option[int])` to `Option[int]`
  unpack(val):
    if isSome it:
      when it is Option[string]:
        if not isEmptyOrWhitespace get it:
          result = some parseInt get it
      when it is Option[int]:
        result = some get it

func toInt*(val: Option[string]): Option[int] =
  ## Convert `Option[string]` to `Option[int]`
  if isSome val:
    if not isEmptyOrWhitespace get val:
      result = some parseInt get val

func to*(val: Option[int]): Option[string] =
  ## Convert `Option[int]` to `Option[string]`
  if isSome val:
    result = some $get val

func to*(val: string): Option[cstring] =
  ## Convert `string` to `Option[cstring]`
  if not isEmptyOrWhitespace val:
    result = some cstring val

func to*(val: Option[seq[cstring]]): Option[seq[string]] =
  ## Convert `Option[seq[cstring]]` to `Option[seq[string]]`
  if isSome val:
    var list: seq[string]
    for item in get(val):
      if item != cstring "":
        list.add $item
    if list.len != 0:
      result = some list

func to*(val: Option[seq[string]]): Option[seq[cstring]] =
  ## Convert `Option[seq[string]]` to `Option[seq[cstring]]`
  if isSome val:
    var list: seq[cstring]
    for item in get(val):
      if not isEmptyOrWhitespace item:
        list.add cstring item
    if list.len != 0:
      result = some list

func to*(val: Option[string]): Option[cstring] =
  ## Convert `Option[string]` to `Option[cstring]`
  if isSome val:
    if not isEmptyOrWhitespace get val:
      result = some cstring get val

func to*(val: Option[cstring]): Option[string] =
  ## Convert `Option[cstring]` to `Option[string]`
  if isSome val:
    if get(val) != cstring "":
      result = some $get(val)

proc log*(msg: string) =
  ## Log messages to the JS console or stdout
  when defined(js):
    console.log cstring msg
  else:
    echo msg

proc logError*(msg: string) = log "ERROR:" & msg
