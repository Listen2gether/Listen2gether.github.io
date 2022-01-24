# Package

version       = "0.1.0"
author        = "snus-kin & tandy-1000"
description   = "Sync your listens on Last.fm and ListenBrainz with other people "
license       = "AGPLv3.0"
srcDir        = "src"
bin           = @["listen2gether"]


# Dependencies
requires "nim >= 1.4.0"
requires "https://gitlab.com/tandy1000/listenbrainz-nim#head"
requires "https://gitlab.com/tandy1000/lastfm-nim#head"
requires "norm"
requires "prologue"
requires "jsony"
requires "karax"

task sass, "Generate css":
  exec "mkdir -p public/css"
  exec "sass src/templates/sass/index.sass public/css/style.css"

task buildjs, "compile templates":
  exec "mkdir -p public/js"
  withDir "src/templates":
    exec "nim js home.nim"
  exec "mv src/templates/home.js public/js"
