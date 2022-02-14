import
  pkg/karax/[karax, kbase, karaxdsl, vdom, kdom],
  std/[asyncjs, jsffi, tables],
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
  storedUsers: Table[cstring, User]

proc onTokenEnter*(ev: Event; n: VNode) =
  ## Routes to mirror page on token enter
  let
    username = $getElementById("username_input").value
    token = $getElementById("token-input").value
    serviceSwitch = getElementById("service_switch").checked
  if serviceSwitch:
    echo "Last.fm users are not supported yet.."
  else:
    if token != "":
      echo "Token entered.."
      # discard validateLB(username, token)

proc onServiceToggleClick*(ev: Event; n: VNode) =
  ## Switches service toggle on click
  if getElementById("service_switch").checked:
    getElementById("token").style.display = "none"
  else:
    getElementById("token").style.display = "flex"

proc storeUser*(db: IndexedDB, dbOptions: IDBOptions, user: User) {.async.} =
  discard await put(db, "user".cstring, toJs user, dbOptions)

proc loadMirror*(service: Service, username, token: string) {.async.} =
  pushState(dom.window.history, 0, cstring"", cstring("/mirror/" & $service & "/" & username & "?token=" & token))

proc renderStoredUsers*(storedUsers: Table[cstring, User]): Vnode =
  var secret: cstring
  result = buildHtml:
    tdiv:
      for userId, user in storedUsers.pairs:
        for serviceUser in user.services:
          if serviceUser.username != "":
            button(id = kstring(userId), class = "row"):
              tdiv(class = "service-icon"):
                case serviceUser.service:
                of Service.listenBrainzService:
                  secret = serviceUser.token
                  img(src = "/public/assets/listenbrainz-logo.svg",
                      id = "listenbrainz-logo",
                      class = "user-icon",
                      alt = "ListenBrainz.org logo"
                  )
                of Service.lastFmService:
                  secret = serviceUser.sessionKey
                  img(src = "/public/assets/lastfm-logo.svg",
                      id = "lastfm-logo",
                      class = "user-icon",
                      alt = "last.fm logo"
                  )
              text serviceUser.username
              proc onclick(ev: kdom.Event; n: VNode) =
                let user = storedUsers[n.id]
                # discard validateLB($serviceUser.username, $secret)

proc returnModal*(): Vnode =
  result = buildHtml:
    tdiv(class = "col login-container"):
      p(id = "body"):
        text "Welcome back!"
      tdiv(id = "username", class = "row textbox"):
        input(`type` = "text", class = "text-input", id = "username_input", placeholder = "Enter username to mirror")
        label(class = "switch"):
          input(`type` = "checkbox", id = "service_switch", oninput = onServiceToggleClick)
          span(class = "slider")
      renderStoredUsers(storedUsers)

proc returnButton: Vnode =
  result = buildHtml:
    tdiv:
      button(id = "return", class = "row login-button"):
        text "🔙"
        proc onclick(ev: kdom.Event; n: VNode) =
          globalServiceView = ServiceView.none

proc submitButton: Vnode =
  result = buildHtml:
    tdiv:
      button(id = "submit", class = "row login-button"):
        text "🆗"
        proc onclick(ev: kdom.Event; n: VNode) =
          echo n.id

proc buttonModal: Vnode =
  result = buildHtml:
    tdiv(id = "button-modal"):
      submitButton()
      returnButton()

proc listenBrainzModal: Vnode =
  result = buildHtml:
    tdiv(id = "listenbrainz-token", class = "row textbox"):
      input(`type` = "text", class = "text-input", id = "token-input", placeholder = "Enter your ListenBrainz token", onkeyupenter = onTokenEnter)

proc lastFmModal: Vnode =
  result = buildHtml:
    tdiv(id = "lastfm-auth"):
      p(id = "body"):
        text "Last.fm users are not currently supported!"

proc serviceModal: Vnode =
  result = buildHtml:
    tdiv(id = "service-modal"):
      for service in Service:
        button(id = kstring($service), class = "row"):
          tdiv(class = "service-logo-button"):
            case service:
            of Service.listenBrainzService:
              img(src = "/public/assets/listenbrainz-logo.svg",
                  id = "listenbrainz-logo",
                  class = "service-logo",
                  alt = "ListenBrainz.org logo"
              )
            of Service.lastFmService:
              img(src = "/public/assets/lastfm-logo.svg",
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
          buttonModal()
        of ServiceView.lastFmService:
          lastFmModal()
          returnButton()

      p(id = "body"):
        text "Enter a username and select a service to start mirroring another user's listens."
      tdiv(id = "username", class = "row textbox"):
        input(`type` = "text", class = "text-input", id = "username_input", placeholder = "Enter username to mirror")
        label(class = "switch"):
          input(`type` = "checkbox", id = "service_switch", oninput = onServiceToggleClick)
          span(class = "slider")

proc getUsers(db: IndexedDB, dbOptions: IDBOptions) {.async.} =
  let objStore = await getAll(db, "user".cstring, dbOptions)
  storedUsers = collect:
    for user in to(objStore, seq[User]): {user.userId: user}
  if storedUsers.len != 0:
    globalSigninView = SigninView.returningUser
  else:
    globalSigninView = SigninView.newUser
  redraw()

proc homeMainSection*(): Vnode =
  ## Generates main section for Home page.
  if storedUsers.len == 0:
    discard getUsers(db, dbOptions)
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
