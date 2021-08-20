import prologue
import prologue / middlewares / staticfile

import sources / [lb, lfm]
import routes / urls
import types
#import models

let
  #db = openDbConn()
  lastFmUser = newServiceUser(service = lastFm,
                              username = "tandy1000")
  listenBrainzUser = newServiceUser(service = listenBrainz,
                                    username = "tandy1000")
  mirroredUser = newUser(services = [lastFmUser, listenBrainzUser])
  #syncListenBrainz = newSyncListenBrainz(mirroredUser.services[listenBrainz].token)
  syncLastFM = newSyncLastFM(sessionKey = mirroredUser.services[lastFm].apiKey)
#db.insertTables()
# syncListenBrainz.validateLbToken(get(clientUser.lbToken))
#let
  #listenPayload = syncListenBrainz.getCurrentTrack(mirroredUser)
  #listenSubmission = syncListenBrainz.listenTrack(listenPayload, listenType="single")
# syncLastFM.getRecentTracks(mirroredUser)
#db.insertListen(listenPayload.listens[0])

# var app = newApp(settings = newSettings(appName = "Listen2gether",
#                                         port = Port(8080)))
# app.use(staticFileMiddleware("src/templates"))
# app.addRoute(urls.urlPatterns, "")
# app.run()