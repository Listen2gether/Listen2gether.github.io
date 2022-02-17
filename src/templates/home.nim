import
  pkg/karax/[karax, kbase, karaxdsl, vdom, kdom],
  std/[asyncjs, jsffi, tables, options],
  pkg/nodejs/jsindexeddb,
  pkg/listenbrainz,
  pkg/listenbrainz/core,
  ../types, share
from std/sugar import collect

var
  db = newIndexedDB()
  dbOptions = IDBOptions(keyPath: "userId")
  lb = newAsyncListenBrainz()
  globalSigninView = SigninView.loadingUsers
  globalServiceView = ServiceView.none
  storedUsers: Table[cstring, User] = initTable[cstring, User]()
  selectedUser: User

proc getUsers(db: IndexedDB, dbOptions: IDBOptions) {.async.} =
  let objStore = await getAll(db, "user".cstring, dbOptions)
  storedUsers = collect:
    for user in to(objStore, seq[User]): {user.userId: user}
  if storedUsers.len != 0:
    globalSigninView = SigninView.returningUser
  else:
    globalSigninView = SigninView.newUser
  redraw()

proc storeUser*(db: IndexedDB, dbOptions: IDBOptions, user: User) {.async.} =
  discard await put(db, "user".cstring, toJs user, dbOptions)

proc validateLBToken(token: string) {.async.} =
  ## Validates a given ListenBrainz token and stores the user.
  let res = await lb.validateToken(token)
  if res.valid:
    lb = newAsyncListenBrainz(token)
    selectedUser = newUser(services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, res.userName.get(), token), Service.lastFmService: newServiceUser(Service.lastFmService)])
    discard storeUser(db, dbOptions, selectedUser)
    discard getUsers(db, dbOptions)

proc loadMirror*(service: Service, username: string) {.async.} =
  pushState(dom.window.history, 0, cstring"", cstring("/mirror/" & $service & "/" & username))

proc serviceToggle: Vnode =
  result = buildHtml:
    tdiv:
      label(class = "switch"):
        input(`type` = "checkbox", id = "service_switch")
          # proc oninput(ev: Event; n: VNode) =
          #   ## Switches service toggle on click
          #   if getElementById("service_switch").checked:
          #     getElementById("token").style.display = "none"
          #   else:
          #     getElementById("token").style.display = "flex"
        span(class = "slider")

proc mirrorUserModal: Vnode =
  result = buildHtml:
    tdiv(id = "mirror-modal"):
      tdiv(id = "username", class = "row textbox"):
        input(`type` = "text", class = "text-input", id = "username-input", placeholder = "Enter username to mirror"):
          proc onkeyupenter(ev: Event; n: VNode) =
            ## Routes to mirror page on token enter
            let
              username = $getElementById("username-input").value
              serviceSwitch = getElementById("service_switch").checked
            if serviceSwitch:
              echo "Last.fm users are not supported yet.."
            else:
              discard loadMirror(Service.listenBrainzService, username)
        serviceToggle()
      button(id = "mirror-button", class = "row login-button"):
        text "Start mirroring!"
        proc onclick(ev: kdom.Event; n: VNode) =
          echo "mirroring..."

proc renderStoredUsers*(storedUsers: Table[cstring, User]): Vnode =
  var
    secret: cstring
    serviceIconId: cstring
    buttonClass: string
  result = buildHtml:
    tdiv:
      for userId, user in storedUsers.pairs:
        buttonClass = "row"
        if not selectedUser.isNil:
          if selectedUser.userId == userId:
            buttonClass = buttonClass & " selected"
        for serviceUser in user.services:
          if serviceUser.username != "":
            button(id = kstring(userId), class = kstring(buttonClass)):
              serviceIconId = $serviceUser.service & "-icon"
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
                # discard validateUser ..
                selectedUser = storedUsers[n.id]
                redraw()

proc returnModal*(): Vnode =
  result = buildHtml:
    tdiv(class = "col login-container"):
      p(id = "body"):
        text "Welcome back!"
      a(id = "link"):
        text "Not you?"
        proc onclick(ev: kdom.Event; n: VNode) =
          globalSigninView = SigninView.newUser
      renderStoredUsers(storedUsers)
      mirrorUserModal()

proc returnButton: Vnode =
  result = buildHtml:
    tdiv:
      button(id = "return", class = "row login-button"):
        text "🔙"
        proc onclick(ev: kdom.Event; n: VNode) =
          globalServiceView = ServiceView.none

proc onTokenEnter(ev: kdom.Event; n: VNode) =
  if $n.id == "listenbrainz-token":
    let token = $getElementById("listenbrainz-token").value
    discard validateLBToken(token)

proc submitButton(service: Service): Vnode =
  let buttonId = $service & "-token"
  result = buildHtml:
    tdiv:
      button(id = kstring(buttonId), class = "row login-button", onclick = onTokenEnter):
        text "🆗"

proc listenBrainzModal: Vnode =
  result = buildHtml:
    tdiv(class = "row textbox"):
      input(`type` = "text", class = "text-input token-input", id = "listenbrainz-token", placeholder = "Enter your ListenBrainz token", onkeyupenter = onTokenEnter)

proc lastFmModal: Vnode =
  result = buildHtml:
    tdiv(id = "lastfm-auth"):
      p(id = "body"):
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
            let id = $n.id
            case id:
            of "listenbrainz":
              globalServiceView = ServiceView.listenBrainzService
            of "lastfm":
              globalServiceView = ServiceView.lastFmService

proc loginModal: Vnode =
  result = buildHtml:
    tdiv(class = "col login-container"):
      p(id = "body"):
        text "Login to your service:"
      tdiv(id = "service-modal-container"):
        case globalServiceView:
        of ServiceView.none:
          serviceModal()
        of ServiceView.listenBrainzService:
          listenBrainzModal()
          buttonModal(Service.listenBrainzService)
        of ServiceView.lastFmService:
          lastFmModal()
          returnButton()

      p(id = "body"):
        text "Enter a username and select a service to start mirroring another user's listens."
      mirrorUserModal()

proc homeMainSection*(): Vnode =
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
        discard getUsers(db, dbOptions)
        loadingModal(cstring "Loading users...")
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
