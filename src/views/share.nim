## Shared view module
## This module holds shared functions and globals to be used across the frontend.
##

import
  std/[asyncjs, times],
  pkg/karax/[karaxdsl, vdom],
  pkg/[listenbrainz, lastfm],
  sources/lfm,
  types, db

type
  AppView* = enum
    ## Stores the overarching state for the webapp:
    ##  - `home`: the home page view is shown.
    ##  - `mirror`: the mirror page view is shown.
    ##  - `loading`: a loading state is shown.
    ##  - `error`: an error state is shown.
    home, mirror, loading, error

var
  globalView*: AppView = AppView.home
  fmClient: AsyncLastFM = newAsyncLastFM(apiKey, apiSecret)
  lbClient: AsyncListenBrainz = newAsyncListenBrainz()
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
