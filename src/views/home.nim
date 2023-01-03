## Home view module
## Manages the home view for the web app, onboarding users to the mirror page.
##

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
  types, db

type
  OnboardView* = enum
    ## Stores the state for the onboarding modal:
    ##  - `initialise`: a new session is being initialised or an existing one is being restored.
    ##  - `onboard`: a new session is being onboarded.
    ##  - `loading`: the user is being transferred to the mirror page.
    initialise, onboard, loading
  UserView = enum
    ## Stores the state for the user modal:
    ##  - `newUser`: a new user is being selected.
    ##  - `existing`: an existing user is selected.
    newUser, existing
  ServiceView = enum
    ## Stores the state for the service selection view:
    ##  - `selection`: all services are shown to be chosen from.
    ##  - `loading`: a service is loading something, such as a token.
    ##  - `listenBrainzService`: the ListenBrainz service authentication modal will be shown.
    ##  - `lastFmService`: the Last.fm service authentication modal will be shown.
    selection, loading, listenBrainzService, lastFmService
  LastFmAuthView = enum
    ## Stores the state for the Last.fm authentication view:
    ##  - `signin`: The user is provided a link to sign-in on Last.fm.
    ##  - `authorise`: The user is provided with a button to authorise the session.
    signin, authorise
  LastFMSessionView = enum
    ## Stores the state for the Last.fm authentication view at the final step of retrieving the authenticated session:
    ##  - `loading`: The session is being authorised.
    ##  - `success`: The session has been authorised.
    ##  - `fail`: The session has not been authorised.
    loading, success, fail

var
  onboardView* = OnboardView.initialise
  authView = UserView.newUser
  serviceView = ServiceView.selection
  lastFmAuthView = LastFmAuthView.signin
  lastFMSessionView = LastFMSessionView.loading
  mirrorUserView = UserView.newUser
  fmToken: string
  fmEventListener, fmSigninClick, fmAway: bool = false

proc restoreSession*(sess: Session) {.async.} =
  ## Restores a given session by updating and initialising `users`
  for id in sess.users:
    try:
      await updateOrInitUser(id)
    except:
      let err = "Failed to restore user '" & $users[id].username & "'."
      logError err
  if sess.mirror.isSome():
    let mirror = sess.mirror.get()
    try:
      await updateOrInitUser(mirror)
    except:
      let err = "Failed to restore mirror user '" & $users[mirror].username & "'."
      logError err

proc getSessions(auth, mirror: var UserView, sessions: var Table[cstring, Session], dbStore = SESSION_DB_STORE) {.async.} =
  ## Gets the app session from IndexedDB and stores, sets `UserView`s if there are existing app sessions.
  try:
    let res = await get[Session](dbStore)
    if res.len != 0:
      sessions = res
      await restoreSession(sessions[SESSION_ID])
      if sessions[SESSION_ID].users.len != 0:
        auth = UserView.existing
      if sessions[SESSION_ID].mirror.isSome():
        mirror = UserView.existing
    else:
      auth = UserView.newUser
      mirror = UserView.newUser
    redraw()
  except:
    logError "Failed to get sessions from IndexedDB."

proc loadMirror(username: cstring, service: Service) =
  ## Sets the window url and sends information to the mirror view.
  let url: cstring = "/mirror?service=" & cstring($service) & "&username=" & username
  pushState(dom.window.history, 0, "", url)
  onboardView = OnboardView.loading

proc validateMirror(id: cstring) {.async.} =
  ## Validates and gets now playing for user.
  try:
    await updateOrInitUser(id)
    mirrorErrorMessage = ""
    let (id, service) = decodeUserId(id)
    loadMirror(id, service)
  except:
    onboardView = OnboardView.initialise
    mirrorErrorMessage = "Please enter a valid user!"
  redraw()

proc onMirrorClick(ev: Event; n: VNode) =
  ## Callback that routes to mirror view on mirror button click.
  case mirrorUserView:
  of UserView.newUser:
    let mirrorUsername = getElementById("username-input").value
    var mirrorService: Service
    if getElementById("service-switch").checked:
      mirrorService = Service.lastFmService
    else:
      mirrorService = Service.listenBrainzService
    if mirrorUsername != "" and sessions[SESSION_ID].users.len > 0:
      mirrorErrorMessage = ""
      discard validateMirror(id = mirrorUsername & $mirrorService)
      onboardView = OnboardView.loading
    else:
      mirrorErrorMessage = "Please choose a user!"
  of UserView.existing:
    if sessions[SESSION_ID].mirror.isSome and sessions[SESSION_ID].users.len > 0:
      mirrorErrorMessage = ""
      discard validateMirror(sessions[SESSION_ID].mirror.get())
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
  var lbClient = newAsyncListenBrainz()
  let res = await lbClient.validateToken($token)
  if res.valid:
    clientErrorMessage = ""
    lbClient = newAsyncListenBrainz($token)
    let user = await lbClient.initUser(cstring res.userName.get(), token = token)
    await store[User](user, users, USER_DB_STORE)
  else:
    if newUser:
      clientErrorMessage = "Please enter a valid token!"
    else:
      clientErrorMessage = "Token no longer valid!"
      await delete(id, USER_DB_STORE)
    redraw()
  serviceView = ServiceView.selection

proc validateFMSession(user: User, newUser = true) {.async.} =
  ## Validates a given LastFM session key and stores the user.
  var fmClient = newAsyncLastFM(apiKey, apiSecret)
  try:
    let clientUser = await fmClient.initUser(user.username, user.sessionKey)
    clientErrorMessage = ""
    fmClient.sk = $user.sessionKey
    await store[User](clientUser, users, USER_DB_STORE)
  except:
    if newUser:
      clientErrorMessage = "Authorisation failed!"
    else:
      clientErrorMessage = "Session no longer valid!"
      # maybe? serviceView = ServiceView.selection
      await delete(user.id, USER_DB_STORE)
    redraw()

proc renderUsers(session: var Session, users: Table[cstring, User], renderMirror = false): Vnode =
  ## Renders users from a `Session` object.
  ## `renderMirror`: should be true if rendering mirror users.
  result = buildHtml(tdiv(id = "previous-session")):
    for id in session.users:
      let user = users[id]
      button(id = user.id, class = "row selected", username = user.username, service = cstring $user.service):
        tdiv(id = cstring $user.service & "-icon", class = "service-icon")
        text user.username
        proc onclick(ev: Event; n: VNode) =
          if renderMirror:
            if session.mirror.isSome():
              session.mirror = none cstring
            else:
              session.mirror = some user.id
          else:
            let id = n.id
            if id in session.users:
              session.users.delete(session.users.find(cstring id))
            else:
              session.users.add(cstring id)
          discard store[Session](session, sessions, SESSION_DB_STORE)

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
    await initUser(username = cstring resp.session.name, service = Service.lastFmService, sessionKey = cstring resp.session.key)
    lastFmSessionView = LastFmSessionView.success
    serviceView = ServiceView.selection
    lastFmSessionView = LastFmSessionView.loading
  except:
    clientErrorMessage = "Authorisation failed!"
    lastFmSessionView = LastFmSessionView.fail
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
      let link: cstring = "http://www.last.fm/api/auth/?api_key=" & cstring(apiKey) & "&token=" & cstring(fmToken)
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
        of LastFMSessionView.fail:
          img(class = "lfm-auth-status", src = "/assets/retry.svg")
        proc onclick(ev: Event; n: VNode) =
          if lastFmSessionView == LastFMSessionView.fail:
            discard fmClient.getLFMSession()

proc returnButton*(authView: var UserView, serviceView: var ServiceView): Vnode =
  ## Renders the return button.
  result = buildHtml(tdiv):
    button(id = "return", class = "row login-button"):
      p(id = "return-button"):
        text "🔙"
      proc onclick(ev: Event; n: VNode) =
        serviceView = ServiceView.selection
        if users.len > 0:
          authView = UserView.existing

proc listenBrainzModal*: Vnode =
  ## Renders the ListenBrainz authorisation modal.
  result = buildHtml(tdiv):
    tdiv(class = "row textbox"):
      input(`type` = "text", class = "text-input token-input", id = "listenbrainz-token", placeholder = "Enter your ListenBrainz token", onkeyupenter = onLBTokenEnter)
    tdiv(id = "button-modal"):
      button(id = "listenbrainz-token", class = "row login-button", onclick = onLBTokenEnter):
        text "🆗"
      returnButton(authView, serviceView)

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
    case authView:
    of UserView.newUser:
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
          returnButton(authView, serviceView)
    of UserView.existing:
      p(id = "modal-text", class = "body"):
        text "Welcome!"
      tdiv(id = "returning-user"):
        a(id = "link"):
          text "Add another account?"
          proc onclick(ev: Event; n: VNode) =
            authView = UserView.newUser
        renderUsers(sessions[SESSION_ID], users)
        errorModal clientErrorMessage

proc mirrorUserModal(view: var UserView): Vnode =
  ## Renders the mirror user selection modal.
  result = buildHtml(tdiv(id = "mirror-modal")):
    case mirrorUserView:
    of UserView.newUser:
      p(id = "modal-text", class = "body"):
        text "Enter a username and select a service."
      tdiv(id = "username", class = "row textbox"):
        input(`type` = "text", class = "text-input", id = "username-input", placeholder = "Enter username to mirror", onkeyupenter = onMirrorClick)
        serviceToggle()
    of UserView.existing:
      p(id = "modal-text", class = "body"):
        text "Select a user to mirror..."
      a(id = "link"):
        text "Add another account?"
        proc onclick(ev: Event; n: VNode) =
          sessions[SESSION_ID].mirror = none cstring
          view = UserView.newUser
      renderUsers(sessions[SESSION_ID], users, renderMirror = true)
    errorModal(mirrorErrorMessage)
    button(id = "mirror-button", class = "row login-button", onclick = onMirrorClick):
      text "Start mirroring!"

proc onboardModal*(mirrorModal = true): Vnode =
  ## Renders the signin column.
  result = buildHtml(tdiv(class = "col signin-container")):
    case onboardView:
    of OnboardView.initialise:
      discard getSessions(authView, mirrorUserView, sessions)
      loadingModal "Restoring previous session..."
      onboardView = OnboardView.onboard
    of OnboardView.onboard:
      loginModal()
      if mirrorModal:
        mirrorUserModal(mirrorUserView)
    of OnboardView.loading:
      if sessions[SESSION_ID].mirror.isSome():
        let (username, _) = decodeUserId(sessions[SESSION_ID].mirror.get)
        loadingModal "Loading " & username & "'s listens..."
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
