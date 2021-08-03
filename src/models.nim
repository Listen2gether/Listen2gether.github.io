import norm / [model, sqlite]
import frosty
import types, sources / [lfm, lb]


let DBLOCATION = "listen2gether.db"


type
  UserTable = ref object of Model
    user: string

  ListenTable = ref object of Model
    listen: string
    trackMetadata: TrackMetadataTable

  TrackMetadataTable = ref object of Model
    trackMetadata: string


func newUserTable(user = ""): UserTable =
  UserTable(user: user)


func newTrackMetadataTable(track = ""): TrackMetadataTable =
  TrackMetadataTable(trackMetadata: track)


func newListenTable(
  listen = "",
  track = newTrackMetadataTable()): ListenTable =
  ListenTable(listen: listen, trackMetadata: track)


proc openDbConn*(dbLocation = DBLOCATION): DbConn =
  result = open(dbLocation, "", "", "")


proc insertTables*(db: DbConn) =
  db.createTables(newUserTable())
  db.createTables(newListenTable())
  db.createTables(newTrackMetadataTable())


proc insertUser*(
  db: DbConn,
  user: User) =
  var user = newUserTable(freeze(user))
  db.insert(user)


proc insertListen*(
  db: DbConn,
  listen: Listen) =
  var
    trackMetadata = newTrackMetadataTable(freeze(listen.trackMetadata))
    listen = newListenTable(freeze(listen), trackMetadata)
  db.insert(trackMetadata)
  db.insert(listen)


#proc getListen*(db: DbConn, ): Listen =