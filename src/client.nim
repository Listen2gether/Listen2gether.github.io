import
  pkg/karax/[karax, karaxdsl, vdom, kdom, localstorage],
  std/[strutils, uri, sequtils, tables],
  views/[home, mirror, share],
  sources/utils,
  types

var
  mirrorUsername: cstring
  darkMode: bool = window.matchMedia("(prefers-color-scheme: dark)").matches

proc headerSection: Vnode =
  ## Renders header section to be used on all pages.
  result = buildHtml(header):
    a(class = "header", href = "/"):
      text "Listen"
      span: text "2"
      text "gether"

proc errorSection(message: string): Vnode =
  ## Renders an error view with a given message.
  result = buildHtml(main):
    tdiv(id = "mirror-error"):
      errorModal("Uh Oh!")
      errorModal(message)

proc setDataTheme(darkMode: bool) =
  ## Sets the data-theme according to the given `darkMode` value
  if darkMode:
    document.getElementsByTagName("html")[0].setAttribute(cstring "data-theme", cstring "dark")
  else:
    document.getElementsByTagName("html")[0].setAttribute(cstring "data-theme", cstring "light")

proc darkModeToggle: Vnode =
  ## Renders the dark mode toggle and watches for system color theme changes to automatically adjust the theme.
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", proc(ev: Event) = darkMode = window.matchMedia("(prefers-color-scheme: dark)").matches)
  if hasItem(cstring "dark-mode"):
    darkMode = parseBool $getItem(cstring "dark-mode")
  setDataTheme(darkMode)

  result = buildHtml:
    label(class = "switch"):
      input(`type` = "checkbox", id = "dark-mode-switch", class = "toggle", checked = toChecked darkMode):
        proc onclick(ev: kdom.Event; n: VNode) =
          darkMode = not darkMode
          setDataTheme(darkMode)
          setItem(cstring "dark-mode", cstring $darkMode)
      span(id = "dark-mode-slider", class = "slider")

proc footerSection: Vnode =
  ## Renders footer section to be used on all pages.
  result = buildHtml(footer):
    a(href = "https://www.gnu.org/licenses/agpl-3.0.html"):
      img(src = "/assets/agpl.svg", id = "agpl", class = "icon", alt = "GNU AGPL icon")
    a(href = "https://github.com/Listen2gether/Listen2gether.github.io"):
      img(id = "github", src = "/assets/github-logo.svg", class = "icon", alt = "GitHub Repository")
    darkModeToggle()

proc mirrorRoute =
  ## Routes the user to the mirror view if they use the /mirror URL path.
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
          logError("Mirror user not found!")
        else:
          globalView = ClientView.mirrorView
      except ValueError:
        mirrorErrorMessage = "Invalid service!"
        globalView = ClientView.errorView

proc createDom: VNode =
  ## Renders the web app.
  if mirrorUsername.isNil or globalView == ClientView.homeView:
    mirrorRoute()

  result = buildHtml(tdiv):
    headerSection()
    case globalView:
    of ClientView.homeView:
      home()
    of ClientView.loadingView:
      main:
        loadingModal(cstring("Loading " & $mirrorUsername & "'s listens..."))
    of ClientView.errorView:
      errorSection(mirrorErrorMessage)
    of ClientView.mirrorView:
      mirror(clientService, mirrorService)
    footerSection()

setRenderer createDom
