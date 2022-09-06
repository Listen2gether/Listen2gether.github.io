## Shared view module
## This module holds shared functions and globals to be used across the frontend.
##

import
  std/[asyncjs, times],
  pkg/karax/[karaxdsl, vdom],
  pkg/[listenbrainz, lastfm],
  sources/lfm,
  types

type
  ClientView* = enum
    homeView, mirrorView, loadingView, errorView

var
  globalView*: ClientView = ClientView.homeView
  fmClient*: AsyncLastFM = newAsyncLastFM(apiKey, apiSecret)
  lbClient*: AsyncListenBrainz = newAsyncListenBrainz()
  clientErrorMessage*, mirrorErrorMessage*: cstring = ""

proc initUser(username: cstring, service: Service): Future[User] {.async.} =
  ## Initialises a `User` object given a `username` and `service`.
  case service:
  of Service.listenBrainzService:
    result = await lbClient.initUser(username)
  of Service.lastFmService:
    result = await fmClient.initUser(username)

proc timeToUpdate(lastUpdateTs: int, ms = 60000): bool =
  ## `ms`: The amount of milliseconds to wait before updating the user.
  ## Returns true if it is time to update the user.
  let
    currentTs = int toUnix getTime()
    nextUpdateTs = lastUpdateTs + (ms div 1000)
  if currentTs >= nextUpdateTs: return true

proc updateUser*(user: var User, ms: int) {.async.} =
  ## Updates a `User` object given an `ms` value.
  if timeToUpdate(user.lastUpdateTs, ms):
    case user.service:
    of Service.listenBrainzService:
      user = await lbClient.updateUser(user)
    of Service.lastFmService:
      user = await fmClient.updateUser(user)

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
