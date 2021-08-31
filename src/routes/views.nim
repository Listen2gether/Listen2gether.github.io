import prologue
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
      let syncListenBrainz = newSyncListenBrainz()
      user.services[listenBrainzService].username = usernameParam
      syncListenBrainz.updateUser(user)
    of "lastfm":
      service = lastFmService
      let syncLastFM = newSyncLastFM()
      user.services[lastFmService].username = usernameParam
      syncLastFM.updateUser(user)
  echo user.listenHistory
  resp htmlResponse(mirrorPage(ctx, service, user))