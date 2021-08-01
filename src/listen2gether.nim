import os
import sources/[lb, lfm]
#import models

import prologue
import prologue/middlewares/utils
import prologue/middlewares/staticfile
import ./routes/urls

when isMainModule:
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

  let
    env = loadPrologueEnv(".env")
    settings = newSettings(appName = env.getOrDefault("appName", "Prologue"),
                  debug = env.getOrDefault("debug", true),
                  port = Port(env.getOrDefault("port", 8888)),
                  secretKey = env.getOrDefault("secretKey", "a")
      )

  var app = newApp(settings = settings)

  app.use(staticFileMiddleware(env.getOrDefault("staticDir", "static")))
  app.use(debugRequestMiddleware())
  app.addRoute(urls.urlPatterns, "")
  app.run()