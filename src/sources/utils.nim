when defined(js):
  import std/[jsffi, macros, options]
  import jsony
else:
  import std/options
  import jsony

when defined(js):
  proc replaceReturn(node: var NimNode) =
    var z = 0
    for s in node:
      var son = node[z]
      let jsResolve = ident("jsResolve")
      if son.kind == nnkReturnStmt:
        let value = if son[0].kind != nnkEmpty: nnkCall.newTree(jsResolve, son[0]) else: jsResolve
        node[z] = nnkReturnStmt.newTree(value)
      elif son.kind == nnkAsgn and son[0].kind == nnkIdent and $son[0] == "result":
        node[z] = nnkAsgn.newTree(son[0], nnkCall.newTree(jsResolve, son[1]))
      else:
        replaceReturn(son)
      inc z

  proc isFutureVoid(node: NimNode): bool =
    result = node.kind == nnkBracketExpr and
            node[0].kind == nnkIdent and $node[0] == "Future" and
            node[1].kind == nnkIdent and $node[1] == "void"

  proc generateJsasync(arg: NimNode): NimNode =
    if arg.kind notin {nnkProcDef, nnkLambda, nnkMethodDef, nnkDo}:
        error("Cannot transform this node kind into an async proc." &
              " proc/method definition or lambda node expected.")

    result = arg
    var isVoid = false
    let jsResolve = ident("jsResolve")
    if arg.params[0].kind == nnkEmpty:
      result.params[0] = nnkBracketExpr.newTree(ident("Future"), ident("void"))
      isVoid = true
    elif isFutureVoid(arg.params[0]):
      isVoid = true

    var code = result.body
    replaceReturn(code)
    result.body = nnkStmtList.newTree()

    if len(code) > 0:
      var awaitFunction = quote:
        proc await[T](f: Future[T]): T {.importjs: "(await #)", used.}
      result.body.add(awaitFunction)

      var resolve: NimNode
      if isVoid:
        resolve = quote:
          var `jsResolve` {.importjs: "undefined".}: Future[void]
      else:
        resolve = quote:
          proc jsResolve[T](a: T): Future[T] {.importjs: "#", used.}
          proc jsResolve[T](a: Future[T]): Future[T] {.importjs: "#", used.}
      result.body.add(resolve)
    else:
      result.body = newEmptyNode()
    for child in code:
      result.body.add(child)

    if len(code) > 0 and isVoid:
      var voidFix = quote:
        return `jsResolve`
      result.body.add(voidFix)

    let asyncPragma = quote:
      {.codegenDecl: "async function $2($3)".}

    result.addPragma(asyncPragma[0])
  
  # create a dummy multisync macro that will simply use {.async.} on JS backend
  macro multisync*(prc: untyped): untyped =
    result = newStmtList()
    result.add generateJsasync(prc)

proc camel2snake*(s: string): string =
  ## CanBeFun => can_be_fun
  ## https://forum.nim-lang.org/t/1701
  result = newStringOfCap(s.len)
  for i in 0..<len(s):
    if s[i] in {'A'..'Z'}:
      if i > 0:
        result.add('_')
      result.add(chr(ord(s[i]) + (ord('a') - ord('A'))))
    else:
      result.add(s[i])


template dumpKey*(s: var string, v: string) =
  const v2 = v.camel2snake().toJson() & ":"
  s.add v2


proc dumpHook*[T](s: var string, v: Option[T]) =
  if v.isSome:
    s.dumpHook(v.get())


proc dumpHook*(s: var string, v: object) =
  s.add '{'
  var i = 0
  when compiles(for k, e in v.pairs: discard):
    # Tables and table like objects.
    for k, e in v.pairs:
      if i > 0:
        s.add ','
      s.dumpHook(k)
      s.add ':'
      s.dumpHook(e)
      inc i
  else:
    # Normal objects.
    for k, e in v.fieldPairs:
      when compiles(e.isSome):
        if e.isSome:
          if i > 0:
            s.add ','
          s.dumpKey(k)
          s.dumpHook(e)
          inc i
      else:
        if i > 0:
          s.add ','
        s.dumpKey(k)
        s.dumpHook(e)
        inc i
  s.add '}'