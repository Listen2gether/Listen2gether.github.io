import
  std/[asyncjs, jsffi],
  pkg/karax/[karaxdsl, vdom],
  pkg/nodejs/jsindexeddb,
  ../types

proc storeUser*(db: IndexedDB, dbOptions: IDBOptions, user: User) {.async.} =
  discard await put(db, "user".cstring, toJs user, dbOptions)

proc head*(): Vnode =
  ## Produces HTML head to be used on all server side rendered pages.
  result = buildHtml(head):
    meta(charset="utf-8", name="viewport", content="width=device-width, initial-scale=1")
    title: text "Listen2gether"
    link(rel="icon", href="/public/assets/favicon_square.svg")
    link(rel="stylesheet", href="/public/css/style.css")

proc headerSection*(): Vnode =
  ## Produces header section to be used on all pages.
  result = buildHtml(header):
    a(class = "header", href = "/"):
      text "Listen"
      span: text "2"
      text "gether"

proc footerSection*(): Vnode =
  ## Produces footer section to be used on all pages.
  result = buildHtml(footer):
    a(href = "https://www.gnu.org/licenses/agpl-3.0.html"):
      img(src = "/public/assets/agpl.svg", id = "agpl", class = "icon", alt = "GNU AGPL icon")
    a(href = "https://github.com/Listen2gether/website"):
      img(src = "/public/assets/github-logo.svg", class = "icon", alt = "GitHub Repository")
