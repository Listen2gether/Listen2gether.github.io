import std/[options, strutils]

proc to*(val: string): Option[cstring] =
  ## Convert `string` to `Option[cstring]`
  if val.isEmptyOrWhitespace():
    result = none cstring
  else:
    result = some cstring val

proc to*(val: Option[seq[cstring]]): Option[seq[string]] =
  ## Convert `Option[seq[cstring]]` to `Option[seq[string]]`
  if isSome val:
    var list: seq[string]
    for item in val.get():
      list.add $item
    result = some list
  else:
    result = none seq[string]

proc to*(val: Option[seq[string]]): Option[seq[cstring]] =
  ## Convert `Option[seq[string]]` to `Option[seq[cstring]]`
  if isSome val:
    var list: seq[cstring]
    for item in val.get():
      list.add cstring item
    result = some list
  else:
    result = none seq[cstring]

proc to*(val: Option[string]): Option[cstring] =
  ## Convert `Option[string]` to `Option[cstring]`
  if isSome val:
    result = some cstring get val
  else:
    result = none cstring

proc to*(val: Option[cstring]): Option[string] =
  ## Convert `Option[cstring]` to `Option[string]`
  if isSome val:
    result = some $get(val)
  else:
    result = none string
