import
  pkg/karax/[karax, karaxdsl, vdom, kdom],
  std/[strutils, uri, sequtils, tables],
  views/[home, mirror, share],
  types

var mirrorUsername: cstring

proc initialLoad =
  if ($window.location.pathname) == "/mirror":
    let params = toTable toSeq decodeQuery(($window.location.search).split("?")[1])
    if "username" in params and "service" in params:
      try:
        mirrorUsername = cstring params["username"]
        mirrorService = parseEnum[Service]($params["service"])
        if mirrorUser.isNil and globalView != ClientView.errorView:
          globalView = ClientView.loadingView
          discard getMirrorUser(mirrorUsername, mirrorService)
        elif globalView == ClientView.errorView:
          echo "Error!"
        else:
          globalView = ClientView.mirrorView
      except ValueError:
        mirrorErrorMessage = "Invalid service!"
        globalView = ClientView.errorView

proc createDom: VNode =
  if mirrorUsername.isNil or globalView == ClientView.homeView:
    initialLoad()

  result = buildHtml(tdiv):
    headerSection()
    case globalView:
    of ClientView.homeView:
      main:
        home()
    of ClientView.loadingView:
      main:
        loadingModal(cstring("Loading " & $mirrorUsername & "'s listens..."))
    of ClientView.errorView:
      mirrorError(mirrorErrorMessage)
    of ClientView.mirrorView:
      mirror(clientService, mirrorService)
    footerSection()

setRenderer createDom
