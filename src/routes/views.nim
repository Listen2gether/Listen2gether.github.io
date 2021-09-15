import karax/localstorage
import prologue, listenbrainz, jsony
import ../sources/[lb, lbTypes]
import ../sources/utils
# , lfm]
import ../types

proc home*(ctx: Context) {.async.} =
  resp readFile("src/templates/home.html")

proc mirror*(ctx: Context) {.async.} =
  let
    serviceParam = ctx.getPathParams("service")
    usernameParam = ctx.getPathParams("username")
    userID = serviceParam & usernameParam
  var
    user: User = newUser()
    service: Service
  case serviceParam:
    of "listenbrainz":
      service = listenBrainzService
      let asyncListenBrainz = newAsyncListenBrainz()
      user.services[listenBrainzService].username = usernameParam
      discard asyncListenBrainz.updateUser(user)
      setItem(userID, toJson(user.listenHistory))
    # of "lastfm":
    #   service = lastFmService
    #   let asyncLastFM = newAsyncLastFM()
    #   user.services[lastFmService].username = usernameParam
    #   discard asyncLastFM.updateUser(user)
    #   setItem(userID, toJson(user.listenHistory))
  resp readFile("src/templates/mirror.html")