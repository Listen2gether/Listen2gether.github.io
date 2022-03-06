# Package

version       = "0.1.0"
author        = "tandy-1000"
description   = "Sync your listens on Last.fm and ListenBrainz with other people "
license       = "AGPLv3.0"
srcDir        = "src"
bin           = @["server"]


# Dependencies
requires "nim >= 1.7.1"
requires "nodejs"
requires "https://gitlab.com/tandy1000/listenbrainz-nim#head"
# requires "https://gitlab.com/tandy1000/lastfm-nim#head"
when defined(c):
  requires "prologue"
requires "jsony"
requires "karax"

task sass, "Generate css":
  exec "mkdir -p public/css"
  exec "sass src/templates/sass/index.sass public/css/style.css"

task buildjs, "compile templates":
  exec "mkdir -p public/js"
  exec "nim -o:public/js/client.js js src/templates/client.nim"
