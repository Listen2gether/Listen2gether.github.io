import
  pkg/karax/[karax, kbase, karaxdsl, vdom, kdom],
  std/[asyncjs, tables, strutils, options, jsconsole],
  pkg/nodejs/jsindexeddb,
  pkg/[listenbrainz, lastfm],
  pkg/lastfm/auth,
  pkg/listenbrainz/core,
  ../sources/[lb, lfm],
  ../types,
  share

type
  ServiceView* = enum
    none, listenBrainzService, lastFmService
  SigninView* = enum
    loadingUsers, returningUser, newUser, loadingRoom
  LastFMAuthView = enum
    loading, signin, authorise

var
  homeServiceView: ServiceView = ServiceView.none
  homeSigninView: SigninView = SigninView.loadingUsers
  lastFMAuthView: LastFMAuthView = LastFMAuthView.loading
  fmToken: string

proc getClientUsers(db: IndexedDB, view: var SigninView, dbStore = clientUsersDbStore) {.async.} =
  ## Gets client users from IndexedDB, stores them in `storedClientUsers`, and sets the `SigninView` if there are any existing users.
  try:
    storedClientUsers = await db.getUsers(dbStore)
    if storedClientUsers.len != 0:
      view = SigninView.returningUser
    else:
      view = SigninView.newUser
  except:
    view = SigninView.newUser
  redraw()

proc getMirrorUsers(db: IndexedDB, dbStore = mirrorUsersDbStore) {.async.} =
  ## Gets mirror users from IndexedDB.
  try:
    storedMirrorUsers = await db.getUsers(dbStore)
  except:
    console.log "ERROR: IndexedDB open failed."


proc validateLBToken(token: cstring, userId: cstring = "", store = true) {.async.} =
  ## Validates a given ListenBrainz token and stores the user.
  lbClient = newAsyncListenBrainz()
  let res = await lbClient.validateToken($token)
  if res.valid:
    clientErrorMessage = ""
    lbClient = newAsyncListenBrainz($token)
    if store:
      clientUser = await lbClient.initUser(cstring res.userName.get(), token = token)
      discard storeUser(db, clientUsersDbStore, clientUser)
      discard db.getClientUsers(homeSigninView)
  else:
    if store:
      clientErrorMessage = "Please enter a valid token!"
    else:
      clientErrorMessage = "Token no longer valid!"
      clientUser = nil
      discard db.delete(clientUsersDbStore, userId, dbOptions)
    redraw()

proc validateFMSession(user: ServiceUser, userId: cstring, store = true) {.async.} =
  ## Validates a given LastFM session key and stores the user.
  try:
    clientUser = await fmClient.initUser(user.username, user.sessionKey)
    clientErrorMessage = ""
    fmClient.sk = $user.sessionKey
    if store:
      discard storeUser(db, clientUsersDbStore, clientUser)
      discard db.getClientUsers(homeSigninView)
  except:
    if store:
      clientErrorMessage = "Authorisation failed!"
    else:
      clientErrorMessage = "Session no longer valid!"
      clientUser = nil
      discard db.delete(clientUsersDbStore, userId, dbOptions)
    redraw()

proc serviceToggle: Vnode =
  result = buildHtml:
    label(class = "switch"):
      input(`type` = "checkbox", id = "service-switch", class = "toggle")
      span(id = "service-slider", class = "slider")

proc loadMirror(service: Service, username: cstring) =
  ## Sets the window url and sends information to the mirror view.
  let url = "/mirror?service=" & $service & "&username=" & $username
  pushState(dom.window.history, 0, cstring "", cstring url)

proc validateUser(username: string, service: Service) {.async.} =
  ## Validates and gets now playing for user.
  try:
    case service:
    of Service.listenBrainzService:
      mirrorUser = await lbClient.initUser(username)
    of Service.lastFmService:
      mirrorUser = await fmClient.initUser(username)
    discard storeUser(db, mirrorUsersDbStore, mirrorUser)
    mirrorErrorMessage = ""
    loadMirror(service, username)
  except:
    mirrorErrorMessage = "Please enter a valid user!"
  redraw()

proc onMirrorClick(ev: kdom.Event; n: VNode) =
  ## Routes to mirror page on token enter
  var username = getElementById("username-input").value
  if getElementById("service-switch").checked:
    mirrorService = Service.lastFmService

  ## client user nil error
  if clientUser.isNil:
    clientErrorMessage = "Please login before trying to mirror!"
  else:
    clientErrorMessage = ""

  ## mirror user nil error
  if mirrorUser.isNil and username == "":
    mirrorErrorMessage = "Please choose a user!"
  else:
    mirrorErrorMessage = ""

  if not mirrorUser.isNil and username == "":
    username = mirrorUser.services[mirrorService].username

  if not clientUser.isNil and (not mirrorUser.isNil or username != ""):
    if clientUser.services[mirrorService].username == username:
      homeSigninView = SigninView.loadingRoom
      discard validateUser($username, mirrorService)
    else:
      homeSigninView = SigninView.loadingRoom
      discard validateUser($username, mirrorService)

proc renderUsers(storedUsers: Table[cstring, User], currentUser: var User, currentService: var Service, mirror = false): Vnode =
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
              tdiv(id = kstring serviceIconId, class = "service-icon")
              text serviceUser.username
              proc onclick(ev: kdom.Event; n: VNode) =
                let
                  userId = n.id
                  service = parseEnum[Service]($n.getAttr("title"))
                if currentUser == storedUsers[userId]:
                  currentUser = nil
                else:
                  currentUser = storedUsers[userId]
                  currentService = service
                  if not mirror:
                    if currentService == Service.listenBrainzService:
                      discard validateLBToken(currentUser.services[service].token, userId = currentUser.userId, store = false)
                    elif currentService == Service.listenBrainzService:
                      discard validateFMSession(currentUser.services[service], currentUser.userId, store = false)

proc mirrorUserModal: Vnode =
  result = buildHtml:
    tdiv(id = "mirror-modal"):
      if storedMirrorUsers.len > 0:
        p(id = "modal-text", class = "body"):
          text "Select a user to mirror..."
        renderUsers(storedMirrorUsers, mirrorUser, mirrorService, mirror = true)
      else:
        p(id = "modal-text", class = "body"):
          text "Enter a username and select a service."

      tdiv(id = "username", class = "row textbox"):
        input(`type` = "text", class = "text-input", id = "username-input", placeholder = "Enter username to mirror", onkeyupenter = onMirrorClick)
        serviceToggle()
      errorMessage mirrorErrorMessage
      button(id = "mirror-button", class = "row login-button", onclick = onMirrorClick):
        text "Start mirroring!"

proc returnButton*(serviceView: var ServiceView, signinView: var SigninView): Vnode =
  result = buildHtml:
    tdiv:
      button(id = "return", class = "row login-button"):
        p(id = "return-button"):
          text "🔙"
        proc onclick(ev: kdom.Event; n: VNode) =
          serviceView = ServiceView.none
          if storedClientUsers.len > 0:
            signinView = SigninView.returningUser

proc onLBTokenEnter(ev: kdom.Event; n: VNode) =
  if $n.id == "listenbrainz-token":
    let token = getElementById("listenbrainz-token").value
    if token != "":
      discard validateLBToken token
    else:
      clientErrorMessage = "Please enter a token!"

proc submitButton(service: Service): Vnode =
  let buttonId = $service & "-token"
  result = buildHtml:
    tdiv:
      button(id = kstring(buttonId), class = "row login-button", onclick = onLBTokenEnter):
        text "🆗"

proc listenBrainzModal*: Vnode =
  result = buildHtml:
    tdiv:
      tdiv(class = "row textbox"):
        input(`type` = "text", class = "text-input token-input", id = "listenbrainz-token", placeholder = "Enter your ListenBrainz token", onkeyupenter = onLBTokenEnter)

proc getLFMToken(fm: AsyncLastFM) {.async.} =
  let resp = await fm.getToken()
  fmToken = resp.token
  lastFMAuthView = LastFMAuthView.signin
  redraw()

proc getLFMSession(fm: AsyncLastFM) {.async.} =
  try:
    let resp = await fm.getSession($fmToken)
    fm.sk = resp.session.key
    clientErrorMessage = ""
    clientUser = await fm.initUser(cstring resp.session.name, cstring resp.session.key)
    discard storeUser(db, clientUsersDbStore, clientUser)
    discard db.getClientUsers(homeSigninView)
  except:
    clientErrorMessage = "Authorisation failed!"
    redraw()

proc lastFmModal*: Vnode =
  if fmToken == "":
    discard fmClient.getLFMToken()

  var
    returned = true
    clicked = false

  if lastFMAuthView == LastFMAuthView.signin:
    document.addEventListener("visibilitychange", proc (ev: Event) = returned = not returned)

  result = buildHtml:
    tdiv(id = "lastfm-auth"):
      case lastFMAuthView:
      of LastFMAuthView.loading:
        loadingModal(cstring "Loading...")
      of LastFMAuthView.signin:
        let link = cstring("http://www.last.fm/api/auth/?api_key=" & fmClient.key & "&token=" & fmToken)
        a(id = "auth-button", target = "_blank", href = link, class = "row login-button"):
          text "Sign-in"
          proc onclick(ev: kdom.Event; n: VNode) =
            clicked = true
            if clicked and returned:
              lastFMAuthView = LastFMAuthView.authorise
      of LastFMAuthView.authorise:
        button(id = "auth-button", class = "row login-button"):
          text "Authorise"
          proc onclick(ev: kdom.Event; n: VNode) =
            discard fmClient.getLFMSession()

proc buttonModal*(service: Service, serviceView: var ServiceView, signinView: var SigninView): Vnode =
  result = buildHtml:
    tdiv(id = "button-modal"):
      submitButton service
      returnButton(serviceView, signinView)

proc serviceModal*(view: var ServiceView): Vnode =
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
              view = ServiceView.listenBrainzService
            of Service.lastFmService:
              view = ServiceView.lastFmService

proc returnModal*(view: var SigninView, mirror: bool): Vnode =
  result = buildHtml:
    tdiv(class = "login-container"):
      p(id = "modal-text", class = "body"):
        text "Welcome back!"
      tdiv(id = "returning-user"):
        a(id = "link"):
          text "Not you?"
          proc onclick(ev: kdom.Event; n: VNode) =
            view = SigninView.newUser
        renderUsers(storedClientUsers, clientUser, clientService)
        errorMessage(clientErrorMessage)
      if mirror:
        mirrorUserModal()

proc loginModal*(serviceView: var ServiceView, signinView: var SigninView, mirror: bool): Vnode =
  result = buildHtml:
    tdiv(class = "login-container"):
      tdiv(id = "service-modal-container"):
        p(id = "modal-text", class = "body"):
          text "Login to your service:"
        case serviceView:
        of ServiceView.none:
          serviceModal(serviceView)
        of ServiceView.listenBrainzService:
          errorMessage(clientErrorMessage)
          listenBrainzModal()
          buttonModal(Service.listenBrainzService, serviceView, signinView)
        of ServiceView.lastFmService:
          lastFmModal()
          returnButton(serviceView, signinView)

      if mirror:
        mirrorUserModal()

proc titleCol: Vnode =
  result = buildHtml:
    tdiv(id = "title-container", class = "col"):
      p(id = "title"):
        a(class = "header", href = "/"):
          text "Listen"
          span: text "2"
          text "gether"
        text " is a website for listen parties."
      p(id = "subtitle"):
        text "Whether you're physically in the same room or not."

proc signinCol*(signinView: var SigninView, serviceView: var ServiceView, mirror = true): Vnode =
  result = buildHtml:
    tdiv(id = "signin-container", class = "col"):
      case signinView:
      of SigninView.loadingUsers:
        discard db.getClientUsers(signinView)
        discard db.getMirrorUsers()
        loadingModal(cstring "Loading users...")
      of SigninView.returningUser:
        returnModal(signinView, mirror)
      of SigninView.newUser:
        loginModal(serviceView, signinView, mirror)
      of SigninView.loadingRoom:
        loadingModal(cstring "Loading room...")

proc descriptionCol: Vnode =
  result = buildHtml:
    tdiv(id = "description-container", class = "col"):
      p(class = "body"):
        text "Virtual listen parties are powered by "
        a(class = "header", href = "https://listenbrainz.org/"):
          text "ListenBrainz"
        text " and a "
        a(class = "header", href = "https://matrix.org/"):
          text "Matrix"
        text " chatroom."

proc logoCol: Vnode =
  result = buildHtml:
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

proc mainSection*: Vnode =
  result = buildHtml:
    tdiv(class = "container"):
      titleCol()
      signinCol(homeSigninView, homeServiceView)
      tdiv(class = "break-column")
      descriptionCol()
      logoCol()
