import prologue
import prologue/middlewares/utils
import prologue/middlewares/staticfile

import sources/[lb, lfm]
#import models
import routes/urls

# let
#   #db = openDbConn()
#   clientUser = newUser(username = lbUser, lbToken = some(lbToken))
#   mirroredUser = newUser(username = lbUser1)
#   syncListenBrainz = newSyncListenBrainz(get(clientUser.lbToken))
# #db.insertTables()
# syncListenBrainz.validateLbToken(get(clientUser.lbToken))
# let
#   listenPayload = syncListenBrainz.getCurrentTrack(mirroredUser)
#   listenSubmission = syncListenBrainz.listenTrack(listenPayload, listenType="single")
# #db.insertListen(listenPayload.listens[0])

var app = newApp(settings = newSettings(appName = "Listen2gether",
                                        port = Port(8080)))
app.use(staticFileMiddleware("src/templates"))
app.addRoute(urls.urlPatterns, "")
app.run()