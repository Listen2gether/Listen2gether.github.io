import
  std/[asyncjs, tables, strutils, options],
  pkg/karax/[karax, karaxdsl, vdom, kdom, jstrutils],
  pkg/nodejs/jsindexeddb,
  pkg/[listenbrainz, lastfm],
  pkg/lastfm/auth,
  pkg/listenbrainz/core,
  sources/[lb, lfm, utils],
  views/share,
  types

type
  ServiceView* = enum
    selection, loading, listenBrainzService, lastFmService
  SigninView* = enum
    loadingUsers, returningUser, newUser, loadingRoom
  LastFmAuthView = enum
    signin, authorise

var
  homeServiceView: ServiceView = ServiceView.selection
  homeSigninView: SigninView = SigninView.loadingUsers
  lastFmAuthView: LastFmAuthView = LastFmAuthView.signin
  fmToken: string

proc getClientUsers(db: IndexedDB, view: var SigninView, dbStore = clientUsersDbStore) {.async.} =
  ## Gets client users from IndexedDB, stores them in `storedClientUsers`, and sets the `SigninView` if there are any existing users.
  try:
    let storedUsers = await db.getUsers(dbStore)
    if storedUsers.len != 0:
      storedClientUsers = storedUsers
  except:
    logError "Failed to get client users from IndexedDB."
  if storedClientUsers.len != 0:
    view = SigninView.returningUser
  else:
    view = SigninView.newUser
  redraw()

proc getMirrorUsers(db: IndexedDB, dbStore = mirrorUsersDbStore) {.async.} =
  ## Gets mirror users from IndexedDB.
  try:
    let storedUsers = await db.getUsers(dbStore)
    if storedUsers.len != 0:
      storedMirrorUsers = storedUsers
      redraw()
  except:
    logError "Failed to get mirror users from IndexedDB."

proc loadMirror(service: Service, username: cstring) =
  ## Sets the window url and sends information to the mirror view.
  let url = "/mirror?service=" & $service & "&username=" & $username
  pushState(dom.window.history, 0, cstring "", cstring url)
  homeSigninView = SigninView.loadingUsers

proc validateUser(username: string, service: Service) {.async.} =
  ## Validates and gets now playing for user.
  try:
    case service:
    of Service.listenBrainzService:
      mirrorUser = await lbClient.initUser(username)
    of Service.lastFmService:
      mirrorUser = await fmClient.initUser(username)
    discard db.storeUser(mirrorUsersDbStore, mirrorUser, storedMirrorUsers)
    mirrorErrorMessage = ""
    loadMirror(service, username)
  except:
    mirrorErrorMessage = "Please enter a valid user!"
  redraw()

proc onMirrorClick(ev: kdom.Event; n: VNode) =
  ## Callback that routes to mirror view on mirror button click.
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
    mirrorUsername = $username
    homeSigninView = SigninView.loadingRoom
    discard validateUser($username, mirrorService)

proc serviceToggle: Vnode =
  ## Renders the service selection toggle.
  result = buildHtml(label(class = "switch")):
    input(`type` = "checkbox", id = "service-switch", class = "toggle")
    span(id = "service-slider", class = "slider")

proc validateLBToken(token: cstring, userId: cstring = "", store = true) {.async.} =
  ## Validates a given ListenBrainz token and stores the user.
  lbClient = newAsyncListenBrainz()
  let res = await lbClient.validateToken($token)
  if res.valid:
    clientErrorMessage = ""
    lbClient = newAsyncListenBrainz($token)
    if store:
      clientUser = await lbClient.initUser(cstring res.userName.get(), token = token)
      discard db.storeUser(clientUsersDbStore, clientUser, storedClientUsers)
      discard db.getClientUsers(homeSigninView)
  else:
    if store:
      clientErrorMessage = "Please enter a valid token!"
    else:
      clientErrorMessage = "Token no longer valid!"
      clientUser = nil
      try:
        discard db.delete(clientUsersDbStore, userId, dbOptions)
      except:
        storedClientUsers.del(userId)
    redraw()
  homeServiceView = ServiceView.selection

proc validateFMSession(user: ServiceUser, userId: cstring, store = true) {.async.} =
  ## Validates a given LastFM session key and stores the user.
  try:
    clientUser = await fmClient.initUser(user.username, user.sessionKey)
    clientErrorMessage = ""
    fmClient.sk = $user.sessionKey
    if store:
      discard db.storeUser(clientUsersDbStore, clientUser, storedClientUsers)
      discard db.getClientUsers(homeSigninView)
  except:
    if store:
      clientErrorMessage = "Authorisation failed!"
    else:
      clientErrorMessage = "Session no longer valid!"
      clientUser = nil
      try:
        discard db.delete(clientUsersDbStore, userId, dbOptions)
      except:
        storedClientUsers.del(userId)
    redraw()
  homeServiceView = ServiceView.selection

proc renderUsers(storedUsers: Table[cstring, User], currentUser: var User, currentService: var Service, mirror = false): Vnode =
  ## Renders stored users.
  var
    serviceIconId: cstring
    buttonClass: cstring
  result = buildHtml(tdiv(id = "stored-users")):
    for userId, user in storedUsers.pairs:
      buttonClass = "row"
      if not currentUser.isNil and currentUser.userId == userId:
        buttonClass = buttonClass & cstring " selected"
      for serviceUser in user.services:
        if serviceUser.username != "":
          button(id = userId, title = cstring $serviceUser.username, class = buttonClass, service = cstring $serviceUser.service):
            serviceIconId = cstring $serviceUser.service & "-icon"
            tdiv(id = serviceIconId, class = "service-icon")
            text serviceUser.username
            proc onclick(ev: kdom.Event; n: VNode) =
              let
                userId = n.id
                service = parseEnum[Service]($n.getAttr("service"))
              if currentUser == storedUsers[userId]:
                currentUser = nil
              else:
                currentUser = storedUsers[userId]
                currentService = service
                if not mirror:
                  if currentService == Service.listenBrainzService:
                    homeServiceView = ServiceView.loading
                    discard validateLBToken(currentUser.services[service].token, userId = currentUser.userId, store = false)
                  elif currentService == Service.listenBrainzService:
                    discard validateFMSession(currentUser.services[service], currentUser.userId, store = false)

proc mirrorUserModal: Vnode =
  ## Renders the mirror user selection modal.
  result = buildHtml(tdiv(id = "mirror-modal")):
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
    errorModal(mirrorErrorMessage)
    button(id = "mirror-button", class = "row login-button", onclick = onMirrorClick):
      text "Start mirroring!"

proc onLBTokenEnter(ev: kdom.Event; n: VNode) =
  ## Callback to validate a ListenBrainz token.
  if $n.id == "listenbrainz-token":
    let token = getElementById("listenbrainz-token").value
    if token != "":
      homeServiceView = ServiceView.loading
      discard validateLBToken token
    else:
      clientErrorMessage = "Please enter a token!"

proc listenBrainzModal*: Vnode =
  ## Renders the ListenBrainz authorisation modal.
  result = buildHtml(tdiv):
    tdiv(class = "row textbox"):
      input(`type` = "text", class = "text-input token-input", id = "listenbrainz-token", placeholder = "Enter your ListenBrainz token", onkeyupenter = onLBTokenEnter)

proc getLFMSession(fm: AsyncLastFM) {.async.} =
  ## Gets an authorised Last.fm session.
  try:
    let resp = await fm.getSession($fmToken)
    fm.sk = resp.session.key
    clientErrorMessage = ""
    fmToken = ""
    clientUser = await fm.initUser(cstring resp.session.name, cstring resp.session.key)
    discard db.storeUser(clientUsersDbStore, clientUser, storedClientUsers)
    discard db.getClientUsers(homeSigninView)
  except:
    clientErrorMessage = "Authorisation failed!"
    redraw()
  homeServiceView = ServiceView.selection

proc lastFmModal*: Vnode =
  ## Renders the Last.fm authorisation modal.
  var
    returned = true
    clicked = false

  if lastFmAuthView == LastFmAuthView.signin:
    document.addEventListener("visibilitychange", proc (ev: Event) = returned = not returned)

  result = buildHtml(tdiv(id = "lastfm-auth")):
    case lastFmAuthView:
    of LastFmAuthView.signin:
      let link = cstring "http://www.last.fm/api/auth/?api_key=" & fmClient.key & "&token=" & fmToken
      a(id = "auth-button", target = "_blank", href = link, class = "row login-button"):
        text "Sign-in"
        proc onclick(ev: kdom.Event; n: VNode) =
          clicked = true
          if clicked and returned:
            lastFmAuthView = LastFmAuthView.authorise
    of LastFmAuthView.authorise:
      button(id = "auth-button", class = "row login-button"):
        text "Authorise"
        proc onclick(ev: kdom.Event; n: VNode) =
          discard fmClient.getLFMSession()

proc submitButton(service: Service): Vnode =
  ## Renders the submit button.
  let buttonId = cstring $service & "-token"
  result = buildHtml(tdiv):
    button(id = buttonId, class = "row login-button", onclick = onLBTokenEnter):
      text "🆗"

proc returnButton*(serviceView: var ServiceView, signinView: var SigninView): Vnode =
  ## Renders the return button.
  result = buildHtml(tdiv):
    button(id = "return", class = "row login-button"):
      p(id = "return-button"):
        text "🔙"
      proc onclick(ev: kdom.Event; n: VNode) =
        serviceView = ServiceView.selection
        if storedClientUsers.len > 0:
          signinView = SigninView.returningUser

proc buttonModal*(service: Service, serviceView: var ServiceView, signinView: var SigninView): Vnode =
  ## Renders the submit and return button modal.
  result = buildHtml(tdiv(id = "button-modal")):
    submitButton service
    returnButton(serviceView, signinView)

proc getLFMToken(fm: AsyncLastFM) {.async.} =
  ## Gets a Last.fm token to be authorised.
  try:
    let resp = await fm.getToken()
    fmToken = resp.token
    homeServiceView = ServiceView.lastFmService
  except:
    clientErrorMessage = "Something went wrong. Try turning off your ad blocker."
    homeServiceView = ServiceView.selection
  redraw()

proc serviceModal*(view: var ServiceView): Vnode =
  ## Renders the service selection modal.
  result = buildHtml(tdiv(id = "service-modal")):
    for service in Service:
      button(id = cstring $service, class = "row"):
        tdiv(class = "service-logo-button"):
          case service:
          of Service.listenBrainzService:
            img(src = "/assets/listenbrainz-logo.svg", id = "listenbrainz-logo", class = "service-logo", alt = "ListenBrainz.org logo")
          of Service.lastFmService:
            img(src = "/assets/lastfm-logo.svg", id = "lastfm-logo", class = "service-logo", alt = "last.fm logo")
        proc onclick(ev: kdom.Event; n: VNode) =
          case parseEnum[Service]($n.id):
          of Service.listenBrainzService:
            view = ServiceView.listenBrainzService
          of Service.lastFmService:
            view = ServiceView.loading
            clientErrorMessage = ""
            if fmToken == "":
              discard fmClient.getLFMToken()

proc returnModal*(view: var SigninView, mirrorModal: bool): Vnode =
  ## Renders the returning user modal and the mirror user selection modal if `mirrorModal` is true.
  result = buildHtml(tdiv(class = "login-container")):
    p(id = "modal-text", class = "body"):
      text "Welcome!"
    tdiv(id = "returning-user"):
      a(id = "link"):
        text "Not you?"
        proc onclick(ev: kdom.Event; n: VNode) =
          view = SigninView.newUser
      renderUsers(storedClientUsers, clientUser, clientService)
      errorModal clientErrorMessage
    if mirrorModal:
      mirrorUserModal()

proc loginModal*(serviceView: var ServiceView, signinView: var SigninView, mirrorModal: bool): Vnode =
  ## Renders the login modal and the mirror user selection modal if `mirrorModal` is true.
  result = buildHtml(tdiv(class = "login-container")):
    tdiv(id = "service-modal-container"):
      p(id = "modal-text", class = "body"):
        text "Login to your service:"
      case serviceView:
      of ServiceView.selection:
        serviceModal serviceView
        errorModal clientErrorMessage
      of ServiceView.loading:
        errorModal clientErrorMessage
        loadingModal "Loading..."
      of ServiceView.listenBrainzService:
        errorModal clientErrorMessage
        listenBrainzModal()
        buttonModal(Service.listenBrainzService, serviceView, signinView)
      of ServiceView.lastFmService:
        errorModal clientErrorMessage
        lastFmModal()
        returnButton(serviceView, signinView)
    if mirrorModal:
      mirrorUserModal()

proc signinModal*(signinView: var SigninView, serviceView: var ServiceView, mirrorModal = true): Vnode =
  ## Renders the signin column.
  result = buildHtml(tdiv(id = "signin-container", class = "col")):
    case signinView:
    of SigninView.loadingUsers:
      discard db.getClientUsers(signinView)
      discard db.getMirrorUsers()
      loadingModal "Loading users..."
    of SigninView.returningUser:
      returnModal(signinView, mirrorModal)
    of SigninView.newUser:
      loginModal(serviceView, signinView, mirrorModal)
    of SigninView.loadingRoom:
      loadingModal "Loading " & mirrorUsername & "'s listens..."

proc home*: Vnode =
  ## Renders the main section for home view.
  result = buildHtml(main):
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
      signinModal(homeSigninView, homeServiceView)
      tdiv(class = "break-column")
      tdiv(id = "description-container", class = "col"):
        p(class = "body"):
          text "Virtual listen parties are powered by "
          a(class = "header", href = "https://listenbrainz.org/"):
            text "ListenBrainz"
          text " and a "
          a(class = "header", href = "https://matrix.org/"):
            text "Matrix"
          text " chatroom."
      tdiv(id = "logo-container", class = "col"):
        a(href = "https://listenbrainz.org/", img(src = "/assets/listenbrainz-logo.svg",
          id = "listenbrainz-logo", class = "logo", alt = "ListenBrainz.org logo")
        )
        a(href = "https://matrix.org/", img(src = "/assets/matrix-logo.svg",
          id = "matrix-logo", class = "logo", alt = "Matrix.org logo")
        )
