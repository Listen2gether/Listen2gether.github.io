import prologue

proc home*(ctx: Context) {.async.} =
  resp readFile("src/templates/home.html")