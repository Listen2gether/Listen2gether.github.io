import
  pkg/karax/[karax, karaxdsl, vdom, kdom],
  std/strutils,
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
    tdiv:
      mainSection(user, service)

proc createDom(): VNode =
  var
    service: Service
    username: cstring
  let urlPath = ($window.location.pathname).split("/")
  if urlPath.len == 4:
    service = parseEnum[Service]($urlPath[2])
    username = cstring urlPath[3]
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
