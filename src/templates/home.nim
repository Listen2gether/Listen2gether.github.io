import
  pkg/karax/[karax, kbase, karaxdsl, vdom, kdom],
  std/[asyncjs, jsffi, tables, strutils, options],
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
  dbStore: cstring = "user"
  dbOptions: IDBOptions = IDBOptions(keyPath: "userId")
  lbClient: AsyncListenBrainz = newAsyncListenBrainz()
  globalServiceView: ServiceView = ServiceView.none
  globalSigninView: SigninView = SigninView.loadingUsers
  storedUsers: Table[cstring, User] = initTable[cstring, User]()
  clientUser, mirrorUser: User
  clientErrorMessage, mirrorErrorMessage: string

proc getUsers(db: IndexedDB, dbStore: cstring, dbOptions: IDBOptions) {.async.} =
  ## Gets users from IndexedDB, stores them in `storedUsers`, and sets the `GlobalSignInView` if there are any existing users.
  let objStore = await getAll(db, dbStore, dbOptions)
  storedUsers = collect:
    for user in to(objStore, seq[User]): {user.userId: user}
  if storedUsers.len != 0:
    globalSigninView = SigninView.returningUser
  else:
    globalSigninView = SigninView.newUser
  redraw()

proc storeUser(db: IndexedDB, dbStore: cstring, dbOptions: IDBOptions, user: User) {.async.} =
  ## Stores a user in a given store in IndexedDB.
  discard await put(db, dbStore, toJs user, dbOptions)

proc validateLBToken(token: string, store = true) {.async.} =
  ## Validates a given ListenBrainz token and stores the user.
  lbClient = newAsyncListenBrainz()
  let res = await lbClient.validateToken(token)
  if res.valid:
    lbClient = newAsyncListenBrainz(token)
    clientUser = newUser(services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, res.userName.get(), token), Service.lastFmService: newServiceUser(Service.lastFmService)])
    if store:
      discard storeUser(db, dbStore, dbOptions, clientUser)
      discard getUsers(db, dbStore, dbOptions)
  else:
    if store:
      clientErrorMessage = "Please enter a valid token!"
      redraw()
    else:
      clientErrorMessage = "Token no longer valid!"
      redraw()

proc loadMirror(service: Service, username: string) {.async.} =
  ## Sets the window url and sends information to the mirror view.
  pushState(dom.window.history, 0, cstring"", cstring("/mirror/" & $service & "/" & username))

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
      res = await lbClient.getUserPlayingNow(username)
      payload = res.payload
      user = newUser(services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username = payload.userId), Service.lastFmService: newServiceUser(Service.lastFmService)], latestListenTs = payload.latestListenTs)
    if payload.count == 1:
      user.playingNow = some to payload.listens[0]
    discard storeUser(db, dbStore, dbOptions, user)
  except:
    mirrorErrorMessage = "Please enter a valid user!"
    redraw()

proc onMirror(ev: kdom.Event; n: VNode) =
  ## Routes to mirror page on token enter
  let
    username = $getElementById("username-input").value
    serviceSwitch = getElementById("service_switch").checked
  if clientUser.isNil:
    clientErrorMessage = "Please login before trying to mirror!"
    redraw()
  else:
    if serviceSwitch:
      mirrorErrorMessage = "Last.fm users are not supported yet.."
      redraw()
    else:
      if clientUser.services[Service.listenBrainzService].username == cstring(username):
        mirrorErrorMessage = "Please enter a different user!"
        redraw()
      else:
        discard validateLBUser(username)
        if mirrorUser.isNil:
          mirrorErrorMessage = "Please enter a valid user!"
          redraw()
        else:
          discard loadMirror(Service.listenBrainzService, username)

proc errorMessage(message: string): Vnode =
  result = buildHtml:
    tdiv(class = "error-message"):
      p(id = "error"):
        text message

proc mirrorUserModal: Vnode =
  result = buildHtml:
    tdiv(id = "mirror-modal"):
      tdiv(id = "username", class = "row textbox"):
        input(`type` = "text", class = "text-input", id = "username-input", placeholder = "Enter username to mirror", onkeyupenter = onMirror)
        serviceToggle()
      errorMessage(mirrorErrorMessage)
      button(id = "mirror-button", class = "row login-button", onclick = onMirror):
        text "Start mirroring!"

proc renderStoredUsers(storedUsers: Table[cstring, User], clientUser: var User): Vnode =
  var
    secret, serviceIconId: cstring
    buttonClass: string
  result = buildHtml:
    tdiv(id = "stored-users"):
      for userId, user in storedUsers.pairs:
        buttonClass = "row"
        if not clientUser.isNil:
          if clientUser.userId == userId:
            buttonClass = buttonClass & " selected"
        for serviceUser in user.services:
          if serviceUser.username != "":
            button(id = kstring(userId), title = kstring($serviceUser.service), class = kstring(buttonClass)):
              serviceIconId = cstring($serviceUser.service & "-icon")
              tdiv(id = kstring(serviceIconId), class = "service-icon"):
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
                clientUser = storedUsers[userId]
                discard validateLBToken($clientUser.services[service].token, store = false)
                redraw()

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
    discard validateLBToken(token)

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
      submitButton(service)
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
      p(class = "body"):
        text "Welcome back!"
      a(id = "link"):
        text "Not you?"
        proc onclick(ev: kdom.Event; n: VNode) =
          globalSigninView = SigninView.newUser
      renderStoredUsers(storedUsers, clientUser)
      errorMessage(clientErrorMessage)
      mirrorUserModal()

proc loginModal: Vnode =
  result = buildHtml:
    tdiv(class = "col login-container"):
      p(class = "body"):
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

      p(class = "body"):
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
        discard getUsers(db, dbStore, dbOptions)
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
