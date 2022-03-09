import
  pkg/karax/[karax, kbase, karaxdsl, vdom, kdom],
  std/[asyncjs, jsffi, tables, strutils, options, times],
  pkg/nodejs/jsindexeddb,
  pkg/listenbrainz,
  pkg/listenbrainz/core,
  ../types, ../sources/lb, share
from std/sugar import collect

type
  ServiceView* = enum
    none, listenBrainzService, lastFmService
  SigninView* = enum
    loadingUsers, returningUser, newUser

var
  db: IndexedDB = newIndexedDB()
  clientUserDbStore: cstring = "clientUser"
  mirrorUserDbStore: cstring = "mirrorUser"
  dbOptions: IDBOptions = IDBOptions(keyPath: "userId")
  lbClient: AsyncListenBrainz = newAsyncListenBrainz()
  globalServiceView: ServiceView = ServiceView.none
  globalSigninView: SigninView = SigninView.loadingUsers
  storedClientUsers: Table[cstring, User] = initTable[cstring, User]()
  storedMirrorUsers: Table[cstring, User] = initTable[cstring, User]()
  clientUser, mirrorUser: User
  clientErrorMessage, mirrorErrorMessage: string

proc getClientUsers(db: IndexedDB, dbStore = clientUserDbStore, dbOptions: IDBOptions = dbOptions) {.async.} =
  ## Gets client users from IndexedDB, stores them in `storedClientUsers`, and sets the `GlobalSignInView` if there are any existing users.
  let objStore = await getAll(db, dbStore, dbOptions)
  storedClientUsers = collect:
    for user in to(objStore, seq[User]): {user.userId: user}
  if storedClientUsers.len != 0:
    globalSigninView = SigninView.returningUser
  else:
    globalSigninView = SigninView.newUser
  redraw()

proc getMirrorUsers(db: IndexedDB, dbStore = mirrorUserDbStore, dbOptions: IDBOptions = dbOptions) {.async.} =
  ## Gets mirror users from IndexedDB.
  let objStore = await getAll(db, dbStore, dbOptions)
  storedMirrorUsers = collect:
    for user in to(objStore, seq[User]): {user.userId: user}

proc storeUser(db: IndexedDB, dbStore: cstring, user: User, dbOptions: IDBOptions = dbOptions) {.async.} =
  ## Stores a user in a given store in IndexedDB.
  discard await put(db, dbStore, toJs user, dbOptions)

proc validateLBToken(token: string, userId: cstring = "", store = true) {.async.} =
  ## Validates a given ListenBrainz token and stores the user.
  lbClient = newAsyncListenBrainz()
  let res = await lbClient.validateToken(token)
  if res.valid:
    lbClient = newAsyncListenBrainz(token)
    if store:
      clientUser = newUser(userId = cstring res.userName.get(), services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, cstring res.userName.get(), token), Service.lastFmService: newServiceUser(Service.lastFmService)])
      discard storeUser(db, clientUserDbStore, clientUser)
      discard db.getClientUsers()
  else:
    if store:
      clientErrorMessage = "Please enter a valid token!"
      redraw()
    else:
      clientErrorMessage = "Token no longer valid!"
      clientUser = nil
      discard db.delete(clientUserDbStore, userId, dbOptions)
      redraw()

proc loadMirror(service: Service, username: cstring) {.async.} =
  ## Sets the window url and sends information to the mirror view.
  let url = "/mirror/" & $service & "/" & $username
  pushState(dom.window.history, 0, cstring "", cstring url)

proc serviceToggle: Vnode =
  result = buildHtml:
    tdiv:
      label(class = "switch"):
        input(`type` = "checkbox", id = "service_switch")
        span(class = "slider")

proc validateLBUser(username: string) {.async.} =
  ## Validates and gets now playing for user.
  try:
    let
      c = newAsyncListenBrainz()
      res = await c.getUserPlayingNow username
      payload = res.payload
      userId = payload.userId
      user = newUser(userId = cstring userId, services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username = cstring payload.userId), Service.lastFmService: newServiceUser(Service.lastFmService)])
    if payload.count == 1:
      user.playingNow = some to payload.listens[0]
      user.latestListenTs = toUnix getTime()
    mirrorUser = user
    discard storeUser(db, mirrorUserDbStore, mirrorUser)
    mirrorErrorMessage = ""
  except:
    mirrorErrorMessage = "Please enter a valid user!"
    redraw()

proc onMirror(ev: kdom.Event; n: VNode) =
  ## Routes to mirror page on token enter
  var username = getElementById("username-input").value
  let serviceSwitch = getElementById("service_switch").checked

  ## client user nil error
  if clientUser.isNil:
    clientErrorMessage = "Please login before trying to mirror!"
    redraw()
  else:
    clientErrorMessage = ""
    redraw()

  ## mirror user nil error
  if mirrorUser.isNil and username == "":
    mirrorErrorMessage = "Please choose a user!"
    redraw()
  else:
    mirrorErrorMessage = ""
    redraw()

  if not mirrorUser.isNil and username == "":
    username = mirrorUser.services[Service.listenBrainzService].username

  if serviceSwitch:
    mirrorErrorMessage = "Last.fm users are not supported yet.."
    redraw()
  else:
    if not clientUser.isNil and (not mirrorUser.isNil or username != ""):
      if clientUser.services[Service.listenBrainzService].username == username:
        mirrorErrorMessage = "Please enter a different user!"
        redraw()
      else:
        discard validateLBUser($username)
        discard loadMirror(Service.listenBrainzService, username)
        redraw()

proc errorMessage(message: string): Vnode =
  result = buildHtml:
    tdiv(class = "error-message"):
      if message != "":
        p(id = "error"):
          text message

proc renderUsers(storedUsers: Table[cstring, User], currentUser: var User, mirror = false): Vnode =
  var
    secret, serviceIconId: cstring
    buttonClass: string
  result = buildHtml:
    tdiv(id = "stored-users"):
      for userId, user in storedUsers.pairs:
        buttonClass = "row"
        if not currentUser.isNil and currentUser.userId == userId:
          buttonClass = buttonClass & " selected"
        for serviceUser in user.services:
          if serviceUser.username != "":
            button(id = kstring userId, title = kstring $serviceUser.service, class = kstring buttonClass):
              serviceIconId = cstring($serviceUser.service & "-icon")
              tdiv(id = kstring serviceIconId, class = "service-icon"):
                case serviceUser.service:
                of Service.listenBrainzService:
                  secret = serviceUser.token
                  img(src = "/assets/listenbrainz-logo.svg",
                      id = "listenbrainz-logo",
                      class = "user-icon",
                      alt = "ListenBrainz.org logo"
                  )
                of Service.lastFmService:
                  secret = serviceUser.sessionKey
                  img(src = "/assets/lastfm-logo.svg",
                      id = "lastfm-logo",
                      class = "user-icon",
                      alt = "last.fm logo"
                  )
              text serviceUser.username
              proc onclick(ev: kdom.Event; n: VNode) =
                let
                  userId = n.id
                  service = parseEnum[Service]($n.getAttr("title"))
                if currentUser.isNil:
                  currentUser = storedUsers[userId]
                  if not mirror:
                    discard validateLBToken($currentUser.services[service].token, userId = currentUser.userId, store = false)
                else:
                  currentUser = nil
                redraw()

proc mirrorUserModal: Vnode =
  result = buildHtml:
    tdiv(id = "mirror-modal"):
      if storedMirrorUsers.len > 0:
        p(id = "modal-text", class = "body"):
          text "Select a user to mirror..."
        renderUsers(storedMirrorUsers, mirrorUser, mirror = true)

      tdiv(id = "username", class = "row textbox"):
        input(`type` = "text", class = "text-input", id = "username-input", placeholder = "Enter username to mirror", onkeyupenter = onMirror)
        serviceToggle()
      errorMessage mirrorErrorMessage
      button(id = "mirror-button", class = "row login-button", onclick = onMirror):
        text "Start mirroring!"

proc returnButton: Vnode =
  result = buildHtml:
    tdiv:
      button(id = "return", class = "row login-button"):
        text "🔙"
        proc onclick(ev: kdom.Event; n: VNode) =
          globalServiceView = ServiceView.none

proc onLBTokenEnter(ev: kdom.Event; n: VNode) =
  if $n.id == "listenbrainz-token":
    let token = $getElementById("listenbrainz-token").value
    discard validateLBToken token

proc submitButton(service: Service): Vnode =
  let buttonId = $service & "-token"
  result = buildHtml:
    tdiv:
      button(id = kstring(buttonId), class = "row login-button", onclick = onLBTokenEnter):
        text "🆗"

proc listenBrainzModal: Vnode =
  result = buildHtml:
    tdiv:
      tdiv(class = "row textbox"):
        input(`type` = "text", class = "text-input token-input", id = "listenbrainz-token", placeholder = "Enter your ListenBrainz token", onkeyupenter = onLBTokenEnter)

proc lastFmModal: Vnode =
  result = buildHtml:
    tdiv(id = "lastfm-auth"):
      p(class = "body"):
        text "Last.fm users are not currently supported!"

proc buttonModal(service: Service): Vnode =
  result = buildHtml:
    tdiv(id = "button-modal"):
      submitButton service
      returnButton()

proc serviceModal: Vnode =
  result = buildHtml:
    tdiv(id = "service-modal"):
      for service in Service:
        button(id = kstring($service), class = "row"):
          tdiv(class = "service-logo-button"):
            case service:
            of Service.listenBrainzService:
              img(src = "/assets/listenbrainz-logo.svg",
                  id = "listenbrainz-logo",
                  class = "service-logo",
                  alt = "ListenBrainz.org logo"
              )
            of Service.lastFmService:
              img(src = "/assets/lastfm-logo.svg",
                  id = "lastfm-logo",
                  class = "service-logo",
                  alt = "last.fm logo"
              )
          proc onclick(ev: kdom.Event; n: VNode) =
            case parseEnum[Service]($n.id):
            of Service.listenBrainzService:
              globalServiceView = ServiceView.listenBrainzService
            of Service.lastFmService:
              globalServiceView = ServiceView.lastFmService

proc returnModal: Vnode =
  result = buildHtml:
    tdiv(class = "col login-container"):
      p(id = "modal-text", class = "body"):
        text "Welcome back!"
      a(id = "link"):
        text "Not you?"
        proc onclick(ev: kdom.Event; n: VNode) =
          globalSigninView = SigninView.newUser
      renderUsers(storedClientUsers, clientUser)
      errorMessage(clientErrorMessage)
      mirrorUserModal()

proc loginModal: Vnode =
  result = buildHtml:
    tdiv(class = "col login-container"):
      p(id = "modal-text", class = "body"):
        text "Login to your service:"
      tdiv(id = "service-modal-container"):
        case globalServiceView:
        of ServiceView.none:
          serviceModal()
        of ServiceView.listenBrainzService:
          errorMessage(clientErrorMessage)
          listenBrainzModal()
          buttonModal(Service.listenBrainzService)
        of ServiceView.lastFmService:
          lastFmModal()
          returnButton()

      p(id = "modal-text", class = "body"):
        text "Enter a username and select a service to start mirroring another user's listens."
      mirrorUserModal()

proc signinSection*: Vnode =
  result = buildHtml:
    tdiv(class = "container"):
      tdiv(id = "title-container", class = "col"):
        p(id = "title"):
          a(class = "header", href = "/"):
            text "Listen"
            span: text "2"
            text "gether"
          text " is a website for listen parties."
        p(id = "subtitle"):
          text "Whether you're physically in the same room or not."
      case globalSigninView:
      of SigninView.loadingUsers:
        discard db.getClientUsers()
        discard db.getMirrorUsers()
        loadingModal(cstring "Loading users...")
      of SigninView.returningUser:
        returnModal()
      of SigninView.newUser:
        loginModal()

proc descriptionSection*: Vnode =
  result = buildHtml:
    tdiv(class = "container"):
      tdiv(id = "description-container", class = "col"):
        p(class = "body"):
          text "Virtual listen parties are powered by ListenBrainz and a Matrix chatroom."
      tdiv(id = "logo-container", class = "col"):
        a(href = "https://listenbrainz.org/",
          img(
            src = "/assets/listenbrainz-logo.svg",
            id = "listenbrainz-logo",
            class = "logo",
            alt = "ListenBrainz.org logo"
          )
        )
        a(href = "https://matrix.org/",
          img(
            src = "/assets/matrix-logo.svg",
            id = "matrix-logo",
            class = "logo",
            alt = "Matrix.org logo"
          )
        )
