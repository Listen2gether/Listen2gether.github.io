# Package

version       = "0.1.0"
author        = "snus-kin & tandy-1000"
description   = "Sync your listens on Last.fm and ListenBrainz with other people "
license       = "AGPLv3.0"
srcDir        = "src"
bin           = @["listen2gether"]


# Dependencies
requires "nim >= 1.5.0"
requires "listenbrainz#head"
requires "lastfm#head"
requires "norm"
requires "https://github.com/tandy-1000/karax/"
requires "prologue"
requires "jsony"

task buildjs, "compile templates":
  withDir "src/templates":
    exec "nim js home.nim"
    exec "nim js mirror.nim"