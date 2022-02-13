import
  pkg/karax/[karax, kbase, karaxdsl, vdom, kdom],
  std/[asyncjs, jsffi, tables],
  pkg/nodejs/jsindexeddb,
  pkg/listenbrainz,
  pkg/listenbrainz/core,
  ../types, share
from std/sugar import collect

type
  SigninView* = enum
    loadingUsers, returningUser, newUser

var
  db = newIndexedDB()
  dbOptions = IDBOptions(keyPath: "userId")
  lb = newAsyncListenBrainz()
  globalSigninView = SigninView.loadingUsers
  storedUsers: Table[cstring, User]

proc getUsers(db: IndexedDB, dbOptions: IDBOptions) {.async.} =
  let objStore = await getAll(db, "user".cstring, dbOptions)
  storedUsers = collect:
    for user in to(objStore, seq[User]): {user.userId: user}
  if storedUsers.len != 0:
    globalSigninView = SigninView.returningUser
  else:
    globalSigninView = SigninView.newUser
  redraw()

proc loadMirror(service: Service, username, token: string) {.async.} =
  pushState(dom.window.history, 0, cstring"", cstring("/mirror/" & $service & "/" & username & "?token=" & token))

proc validateLB(username, token: string) {.async.} =
  # let res = await lb.validateToken(token)
  # if res.valid:
  # use res.userName because that is the client's username
  if true:
    let user = newUser(services = [listenBrainzService: newServiceUser(listenBrainzService, username, token), lastFmService: newServiceUser(lastFmService)])
    discard storeUser(db, dbOptions, user)
    discard loadMirror(Service.listenBrainzService, username, token)

proc onTokenEnter(ev: Event; n: VNode) =
  ## Routes to mirror page on token enter
  let
    username = $getElementById("username_input").value
    token = $getElementById("token_input").value
    serviceSwitch = getElementById("service_switch").checked
  if serviceSwitch:
    # window.location.href = cstring("/mirror/lastfm/" & username)
    echo "not now!"
  else:
    if token != "":
      discard validateLB(username, token)

proc onServiceToggleClick(ev: Event; n: VNode) =
  ## Switches service toggle on click
  if getElementById("service_switch").checked:
    getElementById("token").style.display = "none"
  else:
    getElementById("token").style.display = "flex"

proc loginModal: Vnode =
  result = buildHtml:
    tdiv(id = "login-container", class = "col"):
      p(id = "body"):
        text "Enter a username and select a service to start mirroring another user's listens."
      tdiv(id = "username", class = "row textbox"):
        input(`type` = "text", class = "textinput", id = "username_input", placeholder = "Enter username to mirror")
        label(class = "switch"):
          input(`type` = "checkbox", id = "service_switch", oninput = onServiceToggleClick)
          span(class = "slider")
      tdiv(id = "token", class = "row textbox"):
        input(`type` = "text", class = "textinput", id = "token_input", placeholder = "Enter your ListenBrainz token", onkeyupenter = onTokenEnter)

proc renderStoredUsers: Vnode =
  var secret: cstring
  result = buildHtml:
    tdiv:
      for userId, user in storedUsers.pairs:
        for serviceUser in user.services:
          if serviceUser.username != "":
            button(id = kstring(userId), class = "row"):
              tdiv(class = "service-logo"):
                case serviceUser.service:
                of listenBrainzService:
                  secret = serviceUser.token
                  img(src = "/public/assets/listenbrainz-logo.svg",
                      id = "listenbrainz-logo",
                      class = "user-icon",
                      alt = "ListenBrainz.org logo"
                  )
                of lastFmService:
                  secret = serviceUser.sessionKey
                  img(src = "/public/assets/lastfm-logo.svg",
                      id = "lastfm-logo",
                      class = "user-icon",
                      alt = "last.fm logo"
                  )
              text serviceUser.username
              proc onclick(ev: kdom.Event; n: VNode) =
                let user = storedUsers[n.id]
                discard validateLB($serviceUser.username, $secret)

proc returnModal: Vnode =
  result = buildHtml:
    tdiv(id = "login-container", class = "col"):
      p(id = "body"):
        text "Welcome back!"
      tdiv(id = "username", class = "row textbox"):
        input(`type` = "text", class = "textinput", id = "username_input", placeholder = "Enter username to mirror")
        label(class = "switch"):
          input(`type` = "checkbox", id = "service_switch", oninput = onServiceToggleClick)
          span(class = "slider")
      renderStoredUsers()

proc loadingModal: Vnode =
  result = buildHtml:
    tdiv(id = "login-container", class = "col"):
      p(id = "body"):
        text "Loading users..."
      img(id = "spinner", src = "/public/assets/spinner.svg")

proc mainSection: Vnode =
  ## Generates main section for Home page.
  result = buildHtml(main()):
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
        loadingModal()
      of SigninView.returningUser:
        returnModal()
      of SigninView.newUser:
        loginModal()
    tdiv(class = "container"):
      tdiv(id = "description-container", class = "col"):
        p(id = "body"):
          text "Virtual listen parties are powered by ListenBrainz and a Matrix chatroom."
      tdiv(id = "logo-container", class = "col"):
        a(href = "https://listenbrainz.org/",
          img(
            src = "/public/assets/listenbrainz-logo.svg",
            id = "listenbrainz-logo",
            class = "logo",
            alt = "ListenBrainz.org logo"
          )
        )
        a(href = "https://matrix.org/",
          img(
            src = "/public/assets/matrix-logo.svg",
            id = "matrix-logo",
            class = "logo",
            alt = "Matrix.org logo"
          )
        )

proc createDom(): VNode =
  if storedUsers.len == 0:
    discard getUsers(db, dbOptions)
  result = buildHtml(tdiv):
    headerSection()
    mainSection()
    footerSection()

setRenderer createDom
