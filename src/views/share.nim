import
  std/[asyncjs, jsffi, tables, sugar],
  pkg/karax/[karaxdsl, vdom],
  pkg/nodejs/jsindexeddb,
  pkg/[listenbrainz, lastfm],
  sources/[lfm, utils],
  types

const
  clientUsersDbStore*: cstring = "clientUsers"
  mirrorUsersDbStore*: cstring = "mirrorUsers"

type
  ClientView* = enum
    homeView, mirrorView, loadingView, errorView

var
  globalView*: ClientView = ClientView.homeView
  fmClient*: AsyncLastFM = newAsyncLastFM(apiKey, apiSecret)
  lbClient*: AsyncListenBrainz = newAsyncListenBrainz()
  db*: IndexedDB = newIndexedDB()
  dbOptions*: IDBOptions = IDBOptions(keyPath: "userId")
  clientUsers*: Table[cstring, User] = initTable[cstring, User]()
  mirrorUsers*: Table[cstring, User] = initTable[cstring, User]()
  mirrorUserId*: cstring = ""
  clientErrorMessage*, mirrorErrorMessage*: cstring = ""

proc getSelectedIds*(users: Table[cstring, User]): seq[cstring] =
  for userId, user in users:
    if user.selected:
      result.add userId

proc getUsers*(db: IndexedDB, dbStore: cstring, dbOptions: IDBOptions = dbOptions): Future[Table[cstring, User]] {.async.} =
  ## Gets users from a given IndexedDB store.
  result = initTable[cstring, User]()
  try:
    let objStore = await getAll(db, dbStore, dbOptions)
    if not objStore.isNil:
      result = collect:
        for user in to(objStore, seq[User]): {user.userId: user}
  except:
    logError "Failed to get stored users."

proc storeUser*(db: IndexedDB, user: User, users: var Table[cstring, User], dbStore: cstring, dbOptions: IDBOptions = dbOptions) {.async.} =
  ## Stores a user in a given store in IndexedDB.
  users[user.userId] = user
  try:
    discard put(db, dbStore, toJs user, dbOptions)
  except:
    logError "Failed to store users."

proc errorModal*(message: cstring): Vnode =
  ## Render a div with a given error message
  result = buildHtml:
    tdiv(class = "error-message"):
      if message != "":
        p(id = "error"):
          text message

proc loadingModal*(message: cstring): Vnode =
  ## Renders a div with a loading animation with a given message.
  result = buildHtml:
    tdiv(id = "loading", class = "col signin-container"):
      p(id = "body"):
        text message
      img(id = "spinner", src = "/assets/spinner.svg")
