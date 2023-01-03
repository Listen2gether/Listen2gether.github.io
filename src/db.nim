## Database module
## The web app's database structure is as follows:
## - `Session` table: stores app sessions.
## - `User` table: stores users referenced by an app session.
##

import
  std/[asyncjs, jsffi, tables, sugar, times, strutils],
  pkg/nodejs/jsindexeddb,
  pkg/[listenbrainz, lastfm, jsutils],
  sources/[lb, lfm, utils],
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
    let objStore = await db.getAll(dbStore, dbOptions)
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
    discard db.put(dbStore, toJs obj, dbOptions)
  except:
    logError "Failed to store object."

proc delete*(id, dbStore: cstring, dbOptions = IDBOptions(keyPath: "id")) {.async.} =
  ## Deletes an item given an ID and database store name.`
  try:
    await db.delete(dbStore, id, dbOptions)
  except:
    logError "Failed to delete object."

proc initUser*(username: cstring, service: Service, token, sessionKey: cstring = "") {.async.} =
  ## Initialises a `User` object given a `username` and `service` and stores.
  case service:
  of Service.listenBrainzService:
    let lbClient = newAsyncListenBrainz($token)
    let res = await lbClient.initUser(username, token)
    await store[User](res, users, dbStore = USER_DB_STORE)
  of Service.lastFmService:
    let fmClient: AsyncLastFM = newAsyncLastFM(apiKey, apiSecret, $sessionKey)
    let res = await fmClient.initUser(username, sessionKey)
    await store[User](res, users, dbStore = USER_DB_STORE)

proc timeToUpdate*(lastUpdateTs, ms: int): bool =
  ## `ms`: The amount of milliseconds to wait before updating the user.
  ## Returns true if it is time to update the user.
  let
    currentTs = int toUnix getTime()
    nextUpdateTs = lastUpdateTs + (ms div 1000)
  if currentTs >= nextUpdateTs: return true

proc updateUser*(user: User, ms = 60000) {.async.} =
  ## Updates a given user and stores if it is time to update.
  if timeToUpdate(user.lastUpdateTs, ms):
    case user.service:
    of Service.listenBrainzService:
      let lbClient = newAsyncListenBrainz()
      let res = await lbClient.updateUser(user)
      await store[User](res, users, dbStore = USER_DB_STORE)
    of Service.lastFmService:
      let fmClient: AsyncLastFM = newAsyncLastFM(apiKey, apiSecret)
      let res = await fmClient.updateUser(user)
      await store[User](res, users, dbStore = USER_DB_STORE)

proc decodeUserId*(id: cstring): tuple[username: cstring, service: Service] =
  ## Decodes user IDs into username and service enum.
  ## User IDs are stored in the format of `username:service`.
  let res = split(id, ":")
  return (res[0], parseEnum[Service]($res[1]))

proc updateOrInitUser*(id: cstring, ms = 60000) {.async.} =
  ## Updates or initialises a `User` and stores given an `id` and `ms` value.
  if users.hasKey(id):
    await updateUser(users[id], ms)
  else:
    let user = decodeUserId(id)
    await initUser(user.username, user.service)
