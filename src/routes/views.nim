import pkg/[prologue, lastfm, listenbrainz]
import ../templates/mirror
import ../sources/[lb, lfm]
import ../types

proc home*(ctx: Context) {.async.} =
  resp readFile("src/templates/home.html")

proc mirror*(ctx: Context) {.async.} =
  let
    serviceParam = ctx.getPathParams("service")
    usernameParam = ctx.getPathParams("username")
  var
    user: User = newUser()
    service: Service
  case serviceParam:
    of "listenbrainz":
      service = listenBrainzService
      let asyncListenBrainz = newAsyncListenBrainz()
      user.services[listenBrainzService].username = usernameParam
      asyncCheck asyncListenBrainz.updateUser(user)
    of "lastfm":
      service = lastFmService
      let asyncLastFM = newAsyncLastFM()
      user.services[lastFmService].username = usernameParam
      asyncCheck asyncLastFM.updateUser(user)
  resp htmlResponse(mirrorPage(ctx, service, user))