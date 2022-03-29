# Package

version       = "0.1.0"
author        = "tandy-1000"
description   = "Sync your listens on Last.fm and ListenBrainz with other people "
license       = "AGPLv3.0"
srcDir        = "src"
skipFiles     = @["types.nim"]


# Dependencies
requires "nim >= 1.7.1"
requires "nodejs"
requires "https://gitlab.com/tandy1000/listenbrainz-nim#head"
# requires "https://gitlab.com/tandy1000/lastfm-nim#head"
# requires "https://github.com/tandy-1000/simple-matrix-client == 0.1.0"
requires "jsony"
requires "karax"

task docs, "generate docs!":
  exec "nim doc --project --git.commit:develop --git.url:https://github.com/listen2gether/listen2gether.github.io --outdir:public/docs src/sources/lb.nim"
  exec "mv public/docs/theindex.html public/docs/index.html"
  exec "grep -rl theindex.html public/docs | xargs sed -i 's/theindex.html/index.html/g'"

task sass, "Generate css":
  exec "sass --style=compressed --no-source-map src/templates/sass/index.sass src/style.css"

task buildjs, "compile templates":
  exec "nim -o:src/client.js js src/templates/client.nim"
