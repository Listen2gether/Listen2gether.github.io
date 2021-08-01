import prologue
import prologue/middlewares/utils
import prologue/middlewares/staticfile

import sources/[lb, lfm]
#import models
import urls

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

let settings = newSettings(appName = "Listen2gether",
                           debug = true,
                           port = Port(8080))
var app = newApp(settings = settings)

app.use(staticFileMiddleware("templates"))
app.use(debugRequestMiddleware())
app.addRoute(urls.urlPatterns, "")
app.run()