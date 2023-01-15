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
  db = newIndexedDB()): Future[Table[cstring, T]] {.async.} =
  ## Gets objects from a given IndexedDB location and store in a Table.
  result = initTable[cstring, T]()
  try:
    let objStore = await db.getAll(dbStore, IDBOptions(keyPath: "id"))
    if not objStore.isNil:
      result = collect:
        for obj in to(objStore, seq[T]): {obj.id: obj}
  except:
    logError "Failed to get stored objects."

proc store*[T](
  obj: T,
  dbStore: cstring,
  db = newIndexedDB()) {.async.} =
  ## Stores an object in a given store in IndexedDB.
  try:
    discard db.put(dbStore, toJs obj, IDBOptions(keyPath: "id"))
  except:
    logError "Failed to store object."

proc delete*(
  id, dbStore: cstring,
  db = newIndexedDB()) {.async.} =
  ## Deletes an item given an ID and database store name.`
  try:
    discard db.delete(dbStore, id, IDBOptions(keyPath: "id"))
  except:
    logError "Failed to delete object."

proc updateOrInitSession*(session = newSession()) {.async.} =
  ## Updates or initialises a session and stores.
  if sessions.hasKey(SESSION_ID):
    await store[Session](session, dbStore = SESSION_DB_STORE)
  else:
    await store[Session](session, dbStore = SESSION_DB_STORE)

proc initUser*(
  username: cstring,
  service: Service,
  token, sessionKey: cstring = "") {.async.} =
  ## Initialises a `User` object given a `username` and `service` and stores.
  case service:
  of Service.listenBrainzService:
    let lbClient = newAsyncListenBrainz($token)
    let user = await lbClient.initUser(username, token)
    await store[User](user, dbStore = USER_DB_STORE)
  of Service.lastFmService:
    let fmClient: AsyncLastFM = newAsyncLastFM(apiKey, apiSecret, $sessionKey)
    let user = await fmClient.initUser(username, sessionKey)
    await store[User](user, dbStore = USER_DB_STORE)

proc timeToUpdate*(lastUpdateTs, ms: int): bool =
  ## `ms`: The amount of milliseconds to wait before updating the user.
  ## Returns true if it is time to update the user.
  let
    currentTs = int toUnix getTime()
    nextUpdateTs = lastUpdateTs + (ms div 1000)
  if currentTs >= nextUpdateTs: return true

proc updateUser*(user: User, ms = 60000, token, sessionKey: cstring = "") {.async.} =
  ## Updates a given user and stores if it is time to update.
  if timeToUpdate(user.lastUpdateTs, ms):
    case user.service:
    of Service.listenBrainzService:
      let lbClient = newAsyncListenBrainz($token)
      let user = await lbClient.updateUser(user)
      await store[User](user, dbStore = USER_DB_STORE)
    of Service.lastFmService:
      let fmClient: AsyncLastFM = newAsyncLastFM(apiKey, apiSecret, $sessionKey)
      let user = await fmClient.updateUser(user)
      await store[User](user, dbStore = USER_DB_STORE)

proc decodeUserId*(id: cstring): tuple[username: cstring, service: Service] =
  ## Decodes user IDs into username and service enum.
  ## User IDs are stored in the format of `username:service`.
  let res = split(id, ":")
  return (res[1], parseEnum[Service]($res[0]))

proc updateOrInitUser*(id: cstring, ms = 60000, token, sessionKey: cstring = "") {.async.} =
  ## Updates or initialises a `User` and stores given an `id` and `ms` value.
  if users.hasKey(id):
    await updateUser(users[id], ms, token, sessionKey)
  else:
    let user = decodeUserId(id)
    await initUser(user.username, user.service)
