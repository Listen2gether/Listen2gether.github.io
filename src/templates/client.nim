import
  pkg/karax/[karax, kbase, karaxdsl, vdom, kdom],
  std/[asyncjs, jsffi, tables, strutils],
  pkg/nodejs/jsindexeddb,
  pkg/listenbrainz,
  pkg/listenbrainz/core,
  ../sources/[lb],
  ../types, home, share
from std/sugar import collect

var
  db: IndexedDB = newIndexedDB()
  dbStore: cstring = "user"
  dbOptions: IDBOptions = IDBOptions(keyPath: "userId")
  lbClient: AsyncListenBrainz = newAsyncListenBrainz()
  globalView: ClientView = ClientView.homeView

proc home*: Vnode =
  ## Generates main section for Home page.
  result = buildHtml:
    main:
      signinSection()
      descriptionSection()

proc mirror*(service: Service, username: cstring): Vnode =
  result = buildHtml:
    main:
      tdiv(id = "mirror"):
        p:
          text "You are mirroring "
          a(href = lb.userBaseurl & $username):
            text username & "!"


proc createDom(): VNode =
  var
    service: Service
    username: cstring
  let urlPath = ($window.location.pathname).split("/")
  if urlPath.len == 4:
    service = parseEnum[Service]($urlPath[2])
    username = urlPath[3]
    globalView = ClientView.mirrorView

  result = buildHtml(tdiv):
    headerSection()
    case globalView:
    of homeView:
      home()
    of mirrorView:
      mirror(service, username)
    footerSection()

setRenderer createDom
