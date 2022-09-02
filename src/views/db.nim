## Database module
## The web app's database structure is as follows:
## - Client table: stores one client object per session.
## - User table: stores users used by a client object.
##

import
  std/[asyncjs, jsffi, tables, sugar],
  pkg/nodejs/jsindexeddb,
  sources/utils,
  types

const
  CLIENT_DB_STORE*: cstring = "clients"
  CLIENT_ID*: cstring = "session"
  USER_DB_STORE*: cstring = "users"

var
  db*: IndexedDB = newIndexedDB()
  clients*: Table[cstring, Client] = initTable[cstring, Client]()
  users*: Table[cstring, User] = initTable[cstring, User]()

proc getTable*[T](db: IndexedDB, dbStore: cstring, dbOptions = IDBOptions(keyPath: "id")): Future[Table[cstring, T]] {.async.} =
  ## Gets objects from a given IndexedDB location and store in a Table.
  result = initTable[cstring, T]()
  try:
    let objStore = await getAll(db, dbStore, dbOptions)
    if not objStore.isNil:
      result = collect:
        for obj in to(objStore, seq[T]): {obj.id: obj}
  except:
    logError "Failed to get stored objects."

proc storeTable*[T](db: IndexedDB, obj: T, objs: var Table[cstring, T], dbStore: cstring, dbOptions = IDBOptions(keyPath: "id")) {.async.} =
  ## Stores an object in a given store in IndexedDB.
  objs[obj.id] = obj
  try:
    discard put(db, dbStore, toJs obj, dbOptions)
  except:
    logError "Failed to store object."
