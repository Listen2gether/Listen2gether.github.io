import prologue
import htmlgen

proc index*(ctx: Context) {.async.} =
  resp htmlResponse(h1("Hello World"))