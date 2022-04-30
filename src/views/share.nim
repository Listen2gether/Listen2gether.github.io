import
  std/[asyncjs, jsffi, tables],
  pkg/karax/[karaxdsl, vdom],
  pkg/nodejs/jsindexeddb,
  pkg/[listenbrainz, lastfm],
  sources/[lfm, utils],
  types
from std/sugar import collect

type
  ClientView* = enum
    homeView, mirrorView, loadingView, errorView

var
  globalView*: ClientView = ClientView.homeView
  fmClient*: AsyncLastFM = newAsyncLastFM(apiKey, apiSecret)
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

proc getUsers*(db: IndexedDB, dbStore: cstring, dbOptions: IDBOptions = dbOptions): Future[Table[cstring, User]] {.async.} =
  result = initTable[cstring, User]()
  try:
    let objStore = await getAll(db, dbStore, dbOptions)
    if not isNil objStore:
      result = collect:
        for user in to(objStore, seq[User]): {user.userId: user}
  except:
    logError "Failed to get stored users."

proc storeUser*(db: IndexedDB, dbStore: cstring, user: User, storedUsers: var Table[cstring, User], dbOptions: IDBOptions = dbOptions) {.async.} =
  ## Stores a user in a given store in IndexedDB.
  try:
    let res =  await put(db, dbStore, toJs user, dbOptions)
    if not res:
      storedUsers[user.userId] = user
  except:
    logError "Failed to store users."

proc errorMessage*(message: string): Vnode =
  result = buildHtml:
    tdiv(class = "error-message"):
      if message != "":
        p(id = "error"):
          text message

proc loadingModal*(message: cstring): Vnode =
  result = buildHtml:
    tdiv(id = "loading", class = "col login-container"):
      p(id = "body"):
        text message
      img(id = "spinner", src = "/assets/spinner.svg")
