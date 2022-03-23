import
  std/[strutils, uri, sequtils, tables],
  pkg/karax/[karax, karaxdsl, vdom, kdom],
  ../types,
  home, mirror, share

var
  service: Service
  username: cstring

proc home: Vnode =
  ## Generates main section for Home page.
  result = buildHtml:
    main:
      mainSection()

proc initialLoad =
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
          echo "Error!"
        else:
          globalView = ClientView.mirrorView
      except ValueError:
        mirrorErrorMessage = "Invalid service!"
        globalView = ClientView.errorView

proc createDom(): VNode =
  if username.isNil or globalView == ClientView.homeView:
    initialLoad()

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
