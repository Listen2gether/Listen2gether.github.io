when defined(js):
  import std/jsconsole
import std/[options, strutils]

func to*(val: string): Option[cstring] =
  ## Convert `string` to `Option[cstring]`
  if isEmptyOrWhitespace val:
    result = none cstring
  else:
    result = some cstring val

func to*(val: Option[seq[cstring]]): Option[seq[string]] =
  ## Convert `Option[seq[cstring]]` to `Option[seq[string]]`
  if isSome val:
    var list: seq[string]
    for item in val.get():
      list.add $item
    result = some list
  else:
    result = none seq[string]

func to*(val: Option[seq[string]]): Option[seq[cstring]] =
  ## Convert `Option[seq[string]]` to `Option[seq[cstring]]`
  if isSome val:
    var list: seq[cstring]
    for item in val.get():
      list.add cstring item
    result = some list
  else:
    result = none seq[cstring]

func to*(val: Option[string]): Option[cstring] =
  ## Convert `Option[string]` to `Option[cstring]`
  if isSome val:
    result = some cstring get val
  else:
    result = none cstring

func to*(val: Option[cstring]): Option[string] =
  ## Convert `Option[cstring]` to `Option[string]`
  if isSome val:
    result = some $get(val)
  else:
    result = none string

proc logError*(msg: string) =
  when defined(js):
    console.log cstring("ERROR: " & msg)
  else:
    echo "ERROR: " & msg
