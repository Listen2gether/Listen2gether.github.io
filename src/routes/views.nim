import pkg/prologue

proc index*(ctx: Context) {.async.} =
  resp readFile("public/index.html")

proc mirror*(ctx: Context) {.async.} =
  resp readFile("public/index.html")