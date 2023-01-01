## Database module
## The web app's database structure is as follows:
## - `Session` table: stores app sessions.
## - `User` table: stores users referenced by an app session.
##

import
  std/[asyncjs, jsffi, tables, sugar],
  pkg/nodejs/jsindexeddb,
  sources/utils,
  types

const
  SESSION_DB_STORE*: cstring = "sessions"
  SESSION_ID*: cstring = "session"
  USER_DB_STORE*: cstring = "users"

var
  sessions*: Table[cstring, Session] = initTable[cstring, Session]()
  users*: Table[cstring, User] = initTable[cstring, User]()

proc get*[T](
  dbStore: cstring,
  db = newIndexedDB(),
  dbOptions = IDBOptions(keyPath: "id")): Future[Table[cstring, T]] {.async.} =
  ## Gets objects from a given IndexedDB location and store in a Table.
  result = initTable[cstring, T]()
  try:
    let objStore = await getAll(db, dbStore, dbOptions)
    if not objStore.isNil:
      result = collect:
        for obj in to(objStore, seq[T]): {obj.id: obj}
  except:
    logError "Failed to get stored objects."

proc store*[T](
  obj: T,
  objs: var Table[cstring, T],
  dbStore: cstring,
  db = newIndexedDB(),
  dbOptions = IDBOptions(keyPath: "id")) {.async.} =
  ## Stores an object in a given store in IndexedDB.
  objs[obj.id] = obj
  try:
    discard put(db, dbStore, toJs obj, dbOptions)
  except:
    logError "Failed to store object."

proc delete*(id, dbStore: cstring, dbOptions = IDBOptions(keyPath: "id")) {.async.} =
  ## Deletes an item given an ID and database store name.`
  try:
    let res = await db.delete(dbStore, id, dbOptions)
  except:
    logError "Failed to delete object."

proc initUser*(username: cstring, service: Service): Future[User] {.async.} =
  ## Initialises a `User` object given a `username` and `service`.
  case service:
  of Service.listenBrainzService:
    result = await lbClient.initUser(username)
  of Service.lastFmService:
    result = await fmClient.initUser(username)

proc timeToUpdate(lastUpdateTs, ms: int): bool =
  ## `ms`: The amount of milliseconds to wait before updating the user.
  ## Returns true if it is time to update the user.
  let
    currentTs = int toUnix getTime()
    nextUpdateTs = lastUpdateTs + (ms div 1000)
  if currentTs >= nextUpdateTs: return true

proc decodeUserId*(id: cstring): (cstring, Service) =
  ## Decodes user IDs into username and service enum.
  ## User IDs are stored in the format of `username:service`.
  let res = split($id, ":")
  return (cstring(res[0]), parseEnum(res[1]))

proc updateOrInitUser*(id: cstring, ms = 60000) {.async.} =
  ## Updates or initialises a `User` and stores given an `id` and `ms` value.
  if users[id]:
    if timeToUpdate(users[id].lastUpdateTs, ms):
      case users[id].service:
      of Service.listenBrainzService:
        let res = await lbClient.updateUser(users[id])
        store[User](res, users, dbStore = USER_DB_STORE)
      of Service.lastFmService:
        let res = await fmClient.updateUser(users[id])
        store[User](res, users, dbStore = USER_DB_STORE)
  else:
    store[User](await initUser(&decodeUserId(id)), users, dbStore = USER_DB_STORE)
