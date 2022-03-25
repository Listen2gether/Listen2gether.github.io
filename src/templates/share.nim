import
  std/[asyncjs, jsffi, tables, strutils],
  pkg/karax/[karax, karaxdsl, vdom, kdom, localstorage],
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
  clientService*, mirrorService*: Service
  clientErrorMessage*, mirrorErrorMessage*: string
  darkMode: bool = false

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

proc setDataTheme(darkMode: bool) =
  if darkMode:
    document.getElementsByTagName("html")[0].setAttribute(cstring "data-theme", cstring "dark")
  else:
    document.getElementsByTagName("html")[0].setAttribute(cstring "data-theme", cstring "light")

proc darkModeToggle: Vnode =
  if window.matchMedia("(prefers-color-scheme: dark)").matches:
    darkMode = true
  else:
    darkMode = false
  if hasItem(cstring "dark-mode"):
    darkMode = parseBool $getItem(cstring "dark-mode")
  setDataTheme(darkMode)

  result = buildHtml:
    label(class = "switch"):
      input(`type` = "checkbox", id = "dark-mode-switch", class = "toggle", checked = toChecked darkMode):
        proc onclick(ev: kdom.Event; n: VNode) =
          darkMode = not darkMode
          setDataTheme(darkMode)
          setItem(cstring "dark-mode", cstring $darkMode)
      span(id = "dark-mode-slider", class = "slider")

proc footerSection*(): Vnode =
  ## Produces footer section to be used on all pages.
  result = buildHtml(footer):
    a(href = "https://www.gnu.org/licenses/agpl-3.0.html"):
      img(src = "/assets/agpl.svg", id = "agpl", class = "icon", alt = "GNU AGPL icon")
    a(href = "https://github.com/Listen2gether/Listen2gether.github.io"):
      img(id = "github", src = "/assets/github-logo.svg", class = "icon", alt = "GitHub Repository")
    darkModeToggle()
