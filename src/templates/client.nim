import
  pkg/karax/[karax, karaxdsl, vdom, kdom],
  std/[strutils, uri, sequtils, tables],
  ../types,
  home, mirror, share

proc home: Vnode =
  ## Generates main section for Home page.
  result = buildHtml:
    main:
      mainSection()

proc mirror(service: Service): Vnode =
  ## Generates main section for Mirror page.
  result = buildHtml:
    main:
      mainSection(service)

proc createDom(): VNode =
  var
    service: Service
    username: cstring
  if ($window.location.pathname) == "/mirror":
    let params = toTable toSeq decodeQuery(($window.location.search).split("?")[1])
    if "username" in params and "service" in params:
      try:
        username = cstring params["username"]
        service = parseEnum[Service]($params["service"])
        if mirrorUser.isNil and globalView != ClientView.errorView:
          globalView = ClientView.loadingView
          discard getMirrorUser(username, service)
        elif globalView == ClientView.errorView:
          echo "error!"
        else:
          globalView = ClientView.mirrorView
      except ValueError:
        mirrorErrorMessage = "Invalid service!"
        globalView = ClientView.errorView

  result = buildHtml(tdiv):
    headerSection()
    case globalView:
    of ClientView.homeView:
      home()
    of ClientView.loadingView:
      main:
        loadingModal(cstring("Loading " & $username & "'s listens..."))
    of ClientView.errorView:
      mirrorError(mirrorErrorMessage)
    of ClientView.mirrorView:
      mirror(service)
    footerSection()

setRenderer createDom
