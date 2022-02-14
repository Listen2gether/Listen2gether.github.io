import
  pkg/karax/[karax, kbase, karaxdsl, vdom, kdom],
  std/[asyncjs, jsffi, tables],
  pkg/nodejs/jsindexeddb,
  pkg/listenbrainz,
  pkg/listenbrainz/core,
  ../types, home, share
from std/sugar import collect

var
  db = newIndexedDB()
  dbOptions = IDBOptions(keyPath: "userId")
  lb = newAsyncListenBrainz()
  globalView = ClientView.homeView
  storedUsers: Table[cstring, User]

proc validateLB(username, token: string) {.async.} =
  ## Validates a given ListenBrainz token and stores the user.
  # let res = await lb.validateToken(token)
  # if res.valid:
  # use res.userName because that is the client's username
  if true:
    let user = newUser(services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username, token), Service.lastFmService: newServiceUser(Service.lastFmService)])
    # discard storeUser(db, dbOptions, user)
    # discard loadMirror(Service.listenBrainzService, username, token)

proc createDom(): VNode =
  result = buildHtml(tdiv):
    headerSection()
    case globalView:
    of homeView:
      homeMainSection()
    of mirrorView:
      echo "oi"
    footerSection()

setRenderer createDom
