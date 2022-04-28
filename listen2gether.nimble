# Package

version       = "0.1.0"
author        = "tandy-1000"
description   = "Sync your listens on Last.fm and ListenBrainz with other people "
license       = "AGPLv3.0"
srcDir        = "src"
bin           = @["server"]


# Dependencies
requires "nim >= 1.7.1"
when defined(c):
  requires "prologue"
requires "nodejs"
requires "https://gitlab.com/tandy1000/listenbrainz-nim#head"
requires "https://gitlab.com/tandy1000/lastfm-nim#refactor"
requires "jsony"
requires "karax"

task docs, "generate docs!":
  exec "nim doc --project --git.commit:develop --git.url:https://github.com/listen2gether/listen2gether.github.io --outdir:public/docs src/sources/lb.nim"
  exec "mv public/docs/theindex.html public/docs/index.html"
  exec "grep -rl theindex.html public/docs | xargs sed -i 's/theindex.html/index.html/g'"

task sass, "Generate css":
  exec "mkdir -p public/css"
  exec "sass --style=compressed --no-source-map src/sass/index.sass public/css/style.css"

task buildjs, "compile templates":
  exec "mkdir -p public/js"
  exec "nim -d:danger -o:public/js/client.js js src/client.nim"
