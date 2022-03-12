import
  pkg/karax/[karax, karaxdsl, vdom, kdom],
  std/[strutils, uri, sequtils, tables],
  ../types,
  home, mirror, share

var
  globalView: ClientView = ClientView.homeView

proc home*: Vnode =
  ## Generates main section for Home page.
  result = buildHtml:
    main:
      signinSection()
      descriptionSection()

proc mirror*(user: User, service: Service): Vnode =
  result = buildHtml:
    main:
      mainSection(user, service)

proc createDom(): VNode =
  var
    service: Service
    username: cstring
  if ($window.location.pathname) == "/mirror":
    let params = toTable toSeq decodeQuery(($window.location.search).split("?")[1])
    if "username" in params and "service" in params:
      username = cstring params["username"]
      service = parseEnum[Service]($params["service"])
      globalView = ClientView.mirrorView

  result = buildHtml(tdiv):
    headerSection()
    case globalView:
    of homeView:
      home()
    of mirrorView:
      mirror(mirrorUser, service)
    footerSection()

setRenderer createDom
