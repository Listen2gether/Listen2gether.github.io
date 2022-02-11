import
  pkg/norm/[model, sqlite],
  karax/kbase,
  pkg/jsony,
  sources/[lb, lfm],
  types


const DBLOCATION = "listen2gether.db"


type
  UserTable = ref object of Model
    userID*, userJson*: kstring


func newUserTable(userID, userJson = ""): UserTable =
  UserTable(userID: userID, userJson: userJson)


proc openDbConn*(dbLocation = DBLOCATION): DbConn =
  result = open(dbLocation, "", "", "")


proc createTables*(db: DbConn = openDbConn()) =
  db.createTables(newUserTable())


proc insertUserTable(
  user: User,
  service: Service,
  db: DbConn = openDbConn()): UserTable =
  let userID = user.services[service].baseUrl & user.services[service].username
  var userTable = newUserTable(userID, user.toJson())
  db.insert(userTable)
  return userTable


proc selectUserTable(
  user: User,
  service: Service,
  db: DbConn = openDbConn()): UserTable =
  try:
    result = newUserTable()
    db.select(result, "UserTable.userID = ?", user.services[service].baseUrl)
  except NotFoundError:
    result = insertUserTable(user, service, db)


proc selectUser*(
  user: User,
  service: Service): User =
  let userTable = selectUserTable(user, service)
  result = fromJson(userTable.userJson, User)


proc updateUserTable*(
  user: User,
  service: Service,
  db: DbConn = openDbConn()) =
  var userTable = selectUserTable(user, service, db)
  if userTable == newUserTable():
    discard insertUserTable(user, service, db)
  else:
    userTable.userJson = user.toJson()
    db.update(userTable)
