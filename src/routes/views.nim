import prologue, listenbrainz
import ../sources/[lb]
# , lfm]
import ../types

proc home*(ctx: Context) {.async.} =
  resp readFile("src/templates/home.html")

proc mirror*(ctx: Context) {.async.} =
  resp readFile("src/templates/mirror.html")