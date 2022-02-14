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
