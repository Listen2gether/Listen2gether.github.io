import pkg/norm/[model, pragmas, sqlite]
import pkg/jsony
import types

let DBLOCATION = "listen2gether.db"


type
  UserTable = ref object of Model
    userID* {.unique.}: string
    user*: string


func newUserTable(userID = "", user = ""): UserTable =
  UserTable(userID: userID, user: user)


proc openDbConn*(dbLocation = DBLOCATION): DbConn =
  result = open(dbLocation, "", "", "")


proc createTables*(db: DbConn = openDbConn()) =
  db.createTables(newUserTable())


proc insertUserTable*(
  user: User,
  service: Service,
  db: DbConn = openDbConn()) =
  var userTable = newUserTable(user.services[service].baseUrl, user.toJson())
  db.insert(userTable)


proc selectUserTable(
  user: User,
  service: Service,
  db: DbConn = openDbConn()): UserTable =
  result = newUserTable()
  db.select(result, "UserTable.userID = ?", user.services[service].baseUrl)


proc selectUser*(
  user: User,
  service: Service): User =
  let userTable = selectUserTable(user, service)
  result = fromJson(userTable.user, User)


proc updateUserTable*(
  user: User,
  service: Service,
  db: DbConn = openDbConn()) =
  var userTable = selectUserTable(user, service, db)
  if userTable == newUserTable():
    insertUserTable(user, service, db)
  else:
    userTable.user = user.toJson()
    db.update(userTable)