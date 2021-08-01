import os
import sources/[lb, lfm]
#import models

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