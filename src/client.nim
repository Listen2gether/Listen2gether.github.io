import
  std/strutils,
  pkg/karax/[karax, karaxdsl, vdom, kdom, localstorage, jstrutils],
  views/[home, mirror, share],
  types

var
  darkMode: bool = window.matchMedia("(prefers-color-scheme: dark)").matches
  mirrorUsername: cstring = ""
  mirrorService: Service

proc headerSection: Vnode =
  ## Renders header section to be used on all pages.
  result = buildHtml(header):
    a(class = "header", href = "/"):
      text "Listen"
      span: text "2"
      text "gether"

proc errorSection(message: cstring): Vnode =
  ## Renders an error view with a given message.
  result = buildHtml(main):
    tdiv(id = "mirror-error"):
      errorModal("Uh Oh!")
      errorModal(message)

proc setDataTheme(darkMode: bool) =
  ## Sets the data-theme according to the given `darkMode` value
  if darkMode:
    document.getElementsByTagName("html")[0].setAttribute("data-theme", "dark")
  else:
    document.getElementsByTagName("html")[0].setAttribute("data-theme", "light")

proc darkModeToggle: Vnode =
  ## Renders the dark mode toggle and watches for system color theme changes to automatically adjust the theme.
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", proc(ev: Event) = darkMode = window.matchMedia("(prefers-color-scheme: dark)").matches)
  if hasItem("dark-mode"):
    darkMode = parseBool $getItem("dark-mode")
  setDataTheme(darkMode)
  result = buildHtml:
    label(class = "switch"):
      input(`type` = "checkbox", id = "dark-mode-switch", class = "toggle", checked = toChecked darkMode):
        proc onclick(ev: kdom.Event; n: VNode) =
          darkMode = not darkMode
          setDataTheme(darkMode)
          setItem("dark-mode", & darkMode)
      span(id = "dark-mode-slider", class = "slider")

proc footerSection: Vnode =
  ## Renders footer section to be used on all pages.
  result = buildHtml(footer):
    a(href = "https://www.gnu.org/licenses/agpl-3.0.html"):
      img(src = "/assets/agpl.svg", id = "agpl", class = "icon", alt = "GNU AGPL icon")
    a(href = "https://github.com/Listen2gether/Listen2gether.github.io"):
      img(id = "github", src = "/assets/github-logo.svg", class = "icon", alt = "GitHub Repository")
    darkModeToggle()

proc backButton(ev: Event) =
  globalView = ClientView.homeView
  redraw()

proc createDom: VNode =
  ## Renders the web app.
  window.addEventListener("popstate", backButton)
  if globalView == ClientView.homeView and window.location.pathname == "/mirror":
    (mirrorUsername, mirrorService) = mirrorRoute()
  result = buildHtml(tdiv):
    headerSection()
    case globalView:
    of ClientView.homeView:
      home()
    of ClientView.loadingView:
      main:
        loadingModal "Loading " & mirrorUsername & "'s listens..."
    of ClientView.errorView:
      errorSection mirrorErrorMessage
    of ClientView.mirrorView:
      mirror(mirrorUsername, mirrorService)
    footerSection()

setRenderer createDom
