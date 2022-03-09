import
  std/[asyncjs, jsffi, tables],
  pkg/karax/[karaxdsl, vdom],
  pkg/nodejs/jsindexeddb,
  ../types
from std/sugar import collect

type
  ClientView* = enum
    homeView, mirrorView

var
  db*: IndexedDB = newIndexedDB()
  clientUsersDbStore*: cstring = "clientUsers"
  mirrorUsersDbStore*: cstring = "mirrorUsers"
  dbOptions*: IDBOptions = IDBOptions(keyPath: "userId")
  clientUser*, mirrorUser*: User

proc getUsers*(db: IndexedDB, dbStore: cstring, dbOptions: IDBOptions): Future[Table[cstring, User]] {.async.} =
  let objStore = await getAll(db, dbStore, dbOptions)
  result = collect:
    for user in to(objStore, seq[User]): {user.userId: user}

proc headerSection*(): Vnode =
  ## Produces header section to be used on all pages.
  result = buildHtml(header):
    a(class = "header", href = "/"):
      text "Listen"
      span: text "2"
      text "gether"

proc loadingModal*(message: cstring): Vnode =
  result = buildHtml:
    tdiv(class = "col login-container"):
      p(id = "body"):
        text message
      img(id = "spinner", src = "/assets/spinner.svg")

proc footerSection*(): Vnode =
  ## Produces footer section to be used on all pages.
  result = buildHtml(footer):
    a(href = "https://www.gnu.org/licenses/agpl-3.0.html"):
      img(src = "/assets/agpl.svg", id = "agpl", class = "icon", alt = "GNU AGPL icon")
    a(href = "https://github.com/Listen2gether/Listen2gether.github.io"):
      img(src = "/assets/github-logo.svg", class = "icon", alt = "GitHub Repository")
