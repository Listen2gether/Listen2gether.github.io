import prologue

proc home*(ctx: Context) {.async.} =
  resp readFile("./templates/home.html")