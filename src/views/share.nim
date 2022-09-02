## Shared view module
## This module holds shared functions and globals to be used across the frontend.
##

import
  pkg/karax/[karaxdsl, vdom],
  pkg/[listenbrainz, lastfm],
  sources/lfm

type
  ClientView* = enum
    homeView, mirrorView, loadingView, errorView

var
  globalView*: ClientView = ClientView.homeView
  fmClient*: AsyncLastFM = newAsyncLastFM(apiKey, apiSecret)
  lbClient*: AsyncListenBrainz = newAsyncListenBrainz()
  clientErrorMessage*, mirrorErrorMessage*: cstring = ""

proc errorModal*(message: cstring): Vnode =
  ## Render a div with a given error message
  result = buildHtml(tdiv(class = "error-message")):
    if message != "":
      p(id = "error"):
        text message

proc loadingModal*(message: cstring): Vnode =
  ## Renders a div with a loading animation with a given message.
  result = buildHtml(tdiv(id = "loading", class = "col signin-container")):
    p(id = "body"):
      text message
    img(id = "spinner", src = "/assets/spinner.svg")
