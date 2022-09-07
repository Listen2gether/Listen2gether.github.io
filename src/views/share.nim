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
    ## Stores the overarching state for the webapp:
    ##  - `home`: the home page view is shown.
    ##  - `mirror`: the mirror page view is shown.
    ##  - `loading`: a loading state is shown.
    ##  - `error`: an error state is shown.
    home, mirror, loading, error

var
  globalView*: ClientView = ClientView.home
  fmClient: AsyncLastFM = newAsyncLastFM(apiKey, apiSecret)
  lbClient: AsyncListenBrainz = newAsyncListenBrainz()
  clientErrorMessage*, mirrorErrorMessage*: cstring = ""

proc decodeUserId*(id: cstring): (cstring, Service) =
  ## Decodes user IDs into username and service enum.
  ## User IDs are stored in the format of `username:service`.
  split = split($id, ":")
  return (cstring(split[0]), parseEnum(split[1]))

proc initUser*(username: cstring, service: Service): Future[User] {.async.} =
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

proc updateUser*(user: User, ms: int): Future[User] {.async.} =
  ## Updates a `User` object given an `ms` value.
  if timeToUpdate(user.lastUpdateTs, ms):
    case user.service:
    of Service.listenBrainzService:
      result = await lbClient.updateUser(user)
    of Service.lastFmService:
      result = await fmClient.updateUser(user)

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
