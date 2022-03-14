![Listen2gether](docs/banner.png)

[![Web deployment](https://github.com/Listen2gether/Listen2gether.github.io/actions/workflows/web.yml/badge.svg)](https://github.com/Listen2gether/Listen2gether.github.io/actions/workflows/web.yml)
[![Test](https://github.com/Listen2gether/Listen2gether.github.io/actions/workflows/test.yml/badge.svg)](https://github.com/Listen2gether/Listen2gether.github.io/actions/workflows/test.yml)

Sync your listens on [ListenBrainz](https://listenbrainz.org) with other people.

Currently deployed at https://listen2gether.github.io/.

---

### How to compile

Requirements:
 - Dart Sass

Run the following commands:
```
nimble sass
nimble buildjs
nim r src/server.nim
```
