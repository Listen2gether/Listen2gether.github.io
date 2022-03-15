import
  std/[asyncjs, jsffi, tables],
  pkg/karax/[karaxdsl, vdom],
  pkg/nodejs/jsindexeddb,
  pkg/listenbrainz,
  ../types
from std/sugar import collect

type
  ClientView* = enum
    homeView, mirrorView, loadingView, errorView

var
  globalView*: ClientView = ClientView.homeView
  lbClient*: AsyncListenBrainz = newAsyncListenBrainz()
  db*: IndexedDB = newIndexedDB()
  clientUsersDbStore*: cstring = "clientUsers"
  mirrorUsersDbStore*: cstring = "mirrorUsers"
  dbOptions*: IDBOptions = IDBOptions(keyPath: "userId")
  storedClientUsers*: Table[cstring, User] = initTable[cstring, User]()
  storedMirrorUsers*: Table[cstring, User] = initTable[cstring, User]()
  clientUser*, mirrorUser*: User
  clientErrorMessage*, mirrorErrorMessage*: string

proc getUsers*(db: IndexedDB, dbStore: cstring, dbOptions: IDBOptions = dbOptions): Future[Table[cstring, User]] {.async.} =
  let objStore = await getAll(db, dbStore, dbOptions)
  result = collect:
    for user in to(objStore, seq[User]): {user.userId: user}

proc storeUser*(db: IndexedDB, dbStore: cstring, user: User, dbOptions: IDBOptions = dbOptions) {.async.} =
  ## Stores a user in a given store in IndexedDB.
  discard await put(db, dbStore, toJs user, dbOptions)

proc headerSection*(): Vnode =
  ## Produces header section to be used on all pages.
  result = buildHtml(header):
    a(class = "header", href = "/"):
      text "Listen"
      span: text "2"
      text "gether"

proc errorMessage*(message: string): Vnode =
  result = buildHtml:
    tdiv(class = "error-message"):
      if message != "":
        p(id = "error"):
          text message

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
