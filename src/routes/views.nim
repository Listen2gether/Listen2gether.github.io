import
  pkg/[prologue, lastfm, listenbrainz],
  ../templates/mirror,
  ../sources/lb,
  ../types

proc home*(ctx: Context) {.async.} =
  resp readFile("public/html/home.html")

proc mirror*(ctx: Context) {.async, gcsafe.} =
  let
    serviceParam = ctx.getPathParams("service")
    usernameParam = ctx.getPathParams("username")
  var
    clientUser, mirrorUser: User = newUser()
    service: Service
  case serviceParam:
    of "listenbrainz":
      service = listenBrainzService
      let
        asyncListenBrainz = newAsyncListenBrainz()
        tokenParam = ctx.getQueryParams("token")
      mirrorUser.services[listenBrainzService].username = usernameParam
      clientUser.services[listenBrainzService].token = tokenParam
      waitFor asyncListenBrainz.updateUser(mirrorUser, preMirror = true)
    of "lastfm":
      service = lastFmService
      # let asyncLastFM = newAsyncLastFM()
      # mirrorUser.services[lastFmService].username = usernameParam
      # waitFor asyncLastFM.updateUser(mirrorUser, preMirror = true)
  resp htmlResponse(mirrorPage(ctx, service, mirrorUser))