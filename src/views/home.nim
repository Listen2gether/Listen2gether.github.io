{.experimental: "overloadableEnums".}

import
  std/[dom, asyncjs, tables, strutils, options],
  pkg/karax/[karax, karaxdsl, vdom, jstrutils],
  pkg/nodejs/jsindexeddb,
  pkg/listenbrainz,
  pkg/listenbrainz/core,
  pkg/lastfm,
  pkg/lastfm/auth,
  sources/[lb, lfm, utils],
  views/share,
  types

type
  OnboardView* = enum
    initialise, onboard, loading
  ModalView = enum
    newUser, returningUser
  ServiceView = enum
    selection, loading, listenBrainzService, lastFmService
  LastFmAuthView = enum
    signin, authorise
  LastFMSessionView = enum
    loading, success, retry

var
  onboardView* = OnboardView.initialise
  loginView = ModalView.newUser
  serviceView = ServiceView.selection
  lastFmAuthView = LastFmAuthView.signin
  lastFMSessionView = LastFMSessionView.loading
  mirrorUserView = ModalView.newUser
  fmToken: string
  fmEventListener, fmSigninClick, fmAway: bool = false

proc getUsers(db: IndexedDB, view: var ModalView, storedUsers: var Table[cstring, User], dbStore: cstring) {.async.} =
  ## Gets client users from IndexedDB, stores them in `storedClientUsers`, and sets the `OnboardView` if there are any existing users.
  try:
    let users = await db.getTable[User](dbStore)
    if users.len != 0:
      storedUsers = users
      view = ModalView.returningUser
    else:
      view = ModalView.newUser
    redraw()
  except:
    logError "Failed to get client users from IndexedDB."

proc loadMirror(user: User) =
  ## Sets the window url and sends information to the mirror view.
  let url: cstring = "/mirror?service=" & cstring($user.service) & "&username=" & user.username
  pushState(dom.window.history, 0, "", url)
  onboardView = OnboardView.loading

proc validateMirror(username: cstring, service: Service) {.async.} =
  ## Validates and gets now playing for user.
  var user = newUser(username, service, selected = true)
  mirrorUsers[user.id] = user
  try:
    case service:
    of Service.listenBrainzService:
      user = await lbClient.initUser(username, selected = true)
    of Service.lastFmService:
      user = await fmClient.initUser(username, selected = true)
    discard db.storeTable[User](user, mirrorUsers, mirrorUsersDbStore)
    mirrorErrorMessage = ""
    loadMirror(user)
  except:
    onboardView = OnboardView.initialise
    mirrorErrorMessage = "Please enter a valid user!"
  redraw()

proc onMirrorClick(ev: Event; n: VNode) =
  ## Callback that routes to mirror view on mirror button click.
  let
    selectedClientIds = getSelectedIds(clientUsers)
    selectedMirrorIds = getSelectedIds(mirrorUsers)
  var
    mirrorUsername: cstring = ""
    mirrorService: Service

  case mirrorUserView:
  of ModalView.newUser:
    if selectedMirrorIds.len > 0:
      mirrorUsers[selectedMirrorIds[0]].selected = false
    mirrorUsername = getElementById("username-input").value
    if getElementById("service-switch").checked:
      mirrorService = Service.lastFmService
    else:
      mirrorService = Service.listenBrainzService
    if mirrorUsername != "" and selectedClientIds.len > 0:
      mirrorErrorMessage = ""
      discard validateMirror(mirrorUsername, mirrorService)
      onboardView = OnboardView.loading
    else:
      mirrorErrorMessage = "Please choose a user!"
  of ModalView.returningUser:
    if selectedMirrorIds.len == 1 and mirrorUsers.hasKey(selectedMirrorIds[0]) and selectedClientIds.len > 0:
      mirrorUsername = mirrorUsers[selectedMirrorIds[0]].username
      mirrorService = mirrorUsers[selectedMirrorIds[0]].service
      mirrorErrorMessage = ""
      discard validateMirror(mirrorUsername, mirrorService)
      onboardView = OnboardView.loading
    else:
      mirrorErrorMessage = "Please choose a user!"

proc serviceToggle: Vnode =
  ## Renders the service selection toggle.
  result = buildHtml(label(class = "switch")):
    input(`type` = "checkbox", id = "service-switch", class = "toggle")
    span(id = "service-slider", class = "slider")

proc validateLBToken(token: cstring, id: cstring = "", newUser = true) {.async.} =
  ## Validates a given ListenBrainz token and stores the user.
  lbClient = newAsyncListenBrainz()
  let res = await lbClient.validateToken($token)
  if res.valid:
    clientErrorMessage = ""
    lbClient = newAsyncListenBrainz($token)
    let clientUser = await lbClient.initUser(cstring res.userName.get(), token = token, selected = true)
    discard db.storeTable[User](clientUser, clientUsers, clientUsersDbStore)
    discard db.getUsers(loginView, clientUsers, clientUsersDbStore)
  else:
    if newUser:
      clientErrorMessage = "Please enter a valid token!"
    else:
      clientErrorMessage = "Token no longer valid!"
      try:
        discard db.delete(clientUsersDbStore, id, dbOptions)
      except:
        clientUsers.del(id)
    redraw()
  serviceView = ServiceView.selection

proc validateFMSession(user: User, newUser = true) {.async.} =
  ## Validates a given LastFM session key and stores the user.
  try:
    let clientUser = await fmClient.initUser(user.username, user.sessionKey, selected = true)
    clientErrorMessage = ""
    fmClient.sk = $user.sessionKey
    discard db.storeTable[User](clientUser, clientUsers, clientUsersDbStore)
    discard db.getUsers(loginView, clientUsers, clientUsersDbStore)
  except:
    if newUser:
      clientErrorMessage = "Authorisation failed!"
    else:
      clientErrorMessage = "Session no longer valid!"
      # maybe? serviceView = ServiceView.selection
      try:
        discard db.delete(clientUsersDbStore, user.id, dbOptions)
      except:
        clientUsers.del(user.id)
    redraw()

proc renderUsers(storedUsers: var Table[cstring, User], userDbStore: cstring, mirror = false): Vnode =
  ## Renders stored users, `mirror` should be true if rendering mirror users.
  var
    serviceIconId: cstring
    buttonClass: cstring
  result = buildHtml(tdiv(id = "stored-users")):
    for id, user in storedUsers.pairs:
      buttonClass = "row"
      if user.selected:
        buttonClass = buttonClass & " selected"
      button(id = id, class = buttonClass, username = user.username, service = cstring $user.service):
        serviceIconId = cstring $user.service & "-icon"
        tdiv(id = serviceIconId, class = "service-icon")
        text user.username
        proc onclick(ev: Event; n: VNode) =
          let id = n.id
          if storedUsers[id].selected:
            storedUsers[id].selected = false
            discard db.storeTable[User](storedUsers[id], storedUsers, userDbStore)
          else:
            if mirror:
              let selectedIds = getSelectedIds(mirrorUsers)
              if selectedIds.len > 0:
                storedUsers[selectedIds[0]].selected = false
              storedUsers[id].selected = true
              discard db.storeTable[User](storedUsers[id], storedUsers, userDbStore)
            else:
              storedUsers[id].selected = true
              case storedUsers[id].service
              of Service.listenBrainzService:
                serviceView = ServiceView.loading
                discard validateLBToken(storedUsers[id].token, storedUsers[id].id, newUser = false)
              of Service.lastFmService:
                discard validateFMSession(storedUsers[id], newUser = false)

proc onLBTokenEnter(ev: Event; n: VNode) =
  ## Callback to validate a ListenBrainz token.
  if $n.id == "listenbrainz-token":
    let token = getElementById("listenbrainz-token").value
    if token != "":
      serviceView = ServiceView.loading
      discard validateLBToken token
    else:
      clientErrorMessage = "Please enter a token!"

proc getLFMSession(fm: AsyncLastFM) {.async.} =
  ## Gets an authorised Last.fm session.
  try:
    let resp = await fm.getSession($fmToken)
    fm.sk = resp.session.key
    clientErrorMessage = ""
    fmToken = ""
    let clientUser = await fm.initUser(cstring resp.session.name, cstring resp.session.key)
    discard db.storeTable[User](clientUser, clientUsers, clientUsersDbStore)
    discard db.getUsers(loginView, clientUsers, clientUsersDbStore)
    lastFmSessionView = LastFmSessionView.success
    serviceView = ServiceView.selection
    lastFmSessionView = LastFmSessionView.loading
  except:
    clientErrorMessage = "Authorisation failed!"
    lastFmSessionView = LastFmSessionView.retry
    redraw()

proc handleVisibilityChange(ev: Event) =
  ## Visibility change callback for Last.fm authentication flow
  if fmSigninClick and fmAway and document.hidden == false:
    lastFmAuthView = LastFmAuthView.authorise
    fmEventListener = false
    document.removeEventListener("visibilitychange", handleVisibilityChange)
    discard fmClient.getLFMSession()
  fmAway = document.hidden

proc lastFmModal*: Vnode =
  ## Renders the Last.fm authorisation modal.
  if not fmEventListener:
    fmEventListener = true
    document.addEventListener("visibilitychange", handleVisibilityChange)

  result = buildHtml(tdiv(id = "lastfm-auth")):
    case lastFmAuthView:
    of LastFmAuthView.signin:
      let link: cstring = "http://www.last.fm/api/auth/?api_key=" & cstring(fmClient.key) & "&token=" & cstring(fmToken)
      a(id = "auth-button", target = "_blank", href = link, class = "row login-button"):
        text "Sign-in"
        proc onclick(ev: Event; n: VNode) =
          fmSigninClick = true
    of LastFmAuthView.authorise:
      button(id = "auth-button", class = "row login-button"):
        case lastFmSessionView:
        of LastFMSessionView.loading:
          img(class = "lfm-auth-status", src = "/assets/spinner.svg")
        of LastFMSessionView.success:
          img(class = "lfm-auth-status", src = "/assets/mirrored.svg")
        of LastFMSessionView.retry:
          img(class = "lfm-auth-status", src = "/assets/retry.svg")
        proc onclick(ev: Event; n: VNode) =
          if lastFmSessionView == LastFMSessionView.retry:
            discard fmClient.getLFMSession()

proc returnButton*(loginView: var ModalView, serviceView: var ServiceView): Vnode =
  ## Renders the return button.
  result = buildHtml(tdiv):
    button(id = "return", class = "row login-button"):
      p(id = "return-button"):
        text "🔙"
      proc onclick(ev: Event; n: VNode) =
        serviceView = ServiceView.selection
        if clientUsers.len > 0:
          loginView = ModalView.returningUser

proc listenBrainzModal*: Vnode =
  ## Renders the ListenBrainz authorisation modal.
  result = buildHtml(tdiv):
    tdiv(class = "row textbox"):
      input(`type` = "text", class = "text-input token-input", id = "listenbrainz-token", placeholder = "Enter your ListenBrainz token", onkeyupenter = onLBTokenEnter)
    tdiv(id = "button-modal"):
      button(id = "listenbrainz-token", class = "row login-button", onclick = onLBTokenEnter):
        text "🆗"
      returnButton(loginView, serviceView)

proc getLFMToken(fm: AsyncLastFM) {.async.} =
  ## Gets a Last.fm token to be authorised.
  try:
    let resp = await fm.getToken()
    fmToken = resp.token
    serviceView = ServiceView.lastFmService
  except:
    clientErrorMessage = "Something went wrong. Try turning off your ad blocker."
    serviceView = ServiceView.selection
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
        proc onclick(ev: Event; n: VNode) =
          case parseEnum[Service]($n.id):
          of Service.listenBrainzService:
            view = ServiceView.listenBrainzService
          of Service.lastFmService:
            view = ServiceView.loading
            clientErrorMessage = ""
            discard fmClient.getLFMToken()

proc loginModal: Vnode =
  result = buildHtml(tdiv):
    case loginView:
    of ModalView.newUser:
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
        of ServiceView.lastFmService:
          errorModal clientErrorMessage
          lastFmModal()
          returnButton(loginView, serviceView)
    of ModalView.returningUser:
      p(id = "modal-text", class = "body"):
        text "Welcome!"
      tdiv(id = "returning-user"):
        a(id = "link"):
          text "Add another account?"
          proc onclick(ev: Event; n: VNode) =
            loginView = ModalView.newUser
        renderUsers(clientUsers, clientUsersDbStore)
        errorModal clientErrorMessage

proc mirrorUserModal(view: var ModalView): Vnode =
  ## Renders the mirror user selection modal.
  result = buildHtml(tdiv(id = "mirror-modal")):
    case mirrorUserView:
    of ModalView.newUser:
      p(id = "modal-text", class = "body"):
        text "Enter a username and select a service."
      tdiv(id = "username", class = "row textbox"):
        input(`type` = "text", class = "text-input", id = "username-input", placeholder = "Enter username to mirror", onkeyupenter = onMirrorClick)
        serviceToggle()
    of ModalView.returningUser:
      p(id = "modal-text", class = "body"):
        text "Select a user to mirror..."
      a(id = "link"):
        text "Add another account?"
        proc onclick(ev: Event; n: VNode) =
          let selectedIds = getSelectedIds(mirrorUsers)
          if selectedIds.len == 1:
            mirrorUsers[selectedIds[0]].selected = false
            discard db.storeTable[User](mirrorUsers[selectedIds[0]], mirrorUsers, mirrorUsersDbStore)
          view = ModalView.newUser
      renderUsers(mirrorUsers, mirrorUsersDbStore, mirror = true)
    errorModal(mirrorErrorMessage)
    button(id = "mirror-button", class = "row login-button", onclick = onMirrorClick):
      text "Start mirroring!"

proc onboardModal*(mirrorModal = true): Vnode =
  ## Renders the signin column.
  result = buildHtml(tdiv(class = "col signin-container")):
    case onboardView:
    of OnboardView.initialise:
      discard db.getUsers(loginView, clientUsers, clientUsersDbStore)
      if mirrorModal:
        discard db.getUsers(mirrorUserView, mirrorUsers, mirrorUsersDbStore)
      loadingModal "Loading users..."
      onboardView = OnboardView.onboard
    of OnboardView.onboard:
      loginModal()
      if mirrorModal:
        mirrorUserModal(mirrorUserView)
    of OnboardView.loading:
      let selectedIds = getSelectedIds(mirrorUsers)
      if selectedIds.len > 0:
        loadingModal "Loading " & mirrorUsers[selectedIds[0]].username & "'s listens..."
      else:
        loadingModal "Loading..."

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
      onboardModal()
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
