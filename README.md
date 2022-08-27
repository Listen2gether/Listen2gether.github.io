![Listen2gether](public/assets/banner.png)

[![Web deployment](https://github.com/Listen2gether/Listen2gether.github.io/actions/workflows/web.yml/badge.svg)](https://github.com/Listen2gether/Listen2gether.github.io/actions/workflows/web.yml)
[![Test](https://github.com/Listen2gether/Listen2gether.github.io/actions/workflows/test.yml/badge.svg)](https://github.com/Listen2gether/Listen2gether.github.io/actions/workflows/test.yml)

Sync your listens on [ListenBrainz](https://listenbrainz.org) and [Last.fm](https://last.fm) with other people.

Currently deployed at https://listen2gether.github.io/.

---

### How to compile:

Requirements:
 - Nim
 - Dart Sass
 - HTMLMinifier & UglifyJS (optional)

Run the following commands:
```
nimble sass           ## builds the Sass resources
nimble buildjs        ## builds the app js
nimble minify         ## minifies the html and js (optional)
nimble prep           ## creates app html routes
nimble docs           ## generates documentation
nim r src/server.nim  ## runs the dev webserver
```

---

### Documentation:

Available at https://listen2gether.github.io/docs/.
