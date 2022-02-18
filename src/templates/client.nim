import
  pkg/karax/[karax, kbase, karaxdsl, vdom, kdom],
  std/[asyncjs, jsffi, tables],
  pkg/nodejs/jsindexeddb,
  pkg/listenbrainz,
  pkg/listenbrainz/core,
  ../types, home, share
from std/sugar import collect

var
  db: IndexedDB = newIndexedDB()
  dbStore: cstring = "user"
  dbOptions: IDBOptions = IDBOptions(keyPath: "userId")
  lb: AsyncListenBrainz = newAsyncListenBrainz()
  globalView: ClientView = ClientView.homeView

proc home*: Vnode =
  ## Generates main section for Home page.
  result = buildHtml:
    main:
      signinSection()
      descriptionSection()

proc mirror*: Vnode =
  result = buildHtml:
    main:
      echo "test"

proc createDom(): VNode =
  result = buildHtml(tdiv):
    headerSection()
    case globalView:
    of homeView:
      home()
    of mirrorView:
      echo "oi"
    footerSection()

setRenderer createDom
