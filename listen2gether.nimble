# Package

version       = "0.1.0"
author        = "snus-kin & tandy-1000"
description   = "Sync your listens on Last.fm and ListenBrainz with other people "
license       = "AGPLv3.0"
srcDir        = "src"
bin           = @["listen2gether"]


# Dependencies
requires "nim >= 1.4.0"
requires "listenbrainz"
requires "https://gitlab.com/tandy1000/lastfm-nim.git#head"
requires "norm"
requires "prologue"
requires "jsony"
requires "https://github.com/disruptek/frosty"

task buildjs, "compile templates":
  withDir "src/templates":
    exec "nim js home.nim"
    exec "nim js mirror.nim"