import
  std/[dom, times, options, asyncjs, sequtils, strutils, uri, tables],
  pkg/karax/[karax, karaxdsl, vdom, kdom, jstrutils],
  pkg/jsony,
  sources/[lb, lfm, utils],
  home, share, types

type
  MirrorView = enum
    login, mirroring

var
  mirrorMirrorView = MirrorView.login
  mirrorSigninView = SigninView.loadingUsers
  mirrorServiceView = ServiceView.selection
  listenEndInd: int = 10
  mirrorToggle = true
  polling = false

proc pageListens(ev: Event; n: VNode) =
  ## Backfills the user's listens on scroll event and stores to DB
  let
    increment = 10
    d = n.dom

  if d != nil and ((d.scrollHeight - d.scrollTop) == d.offsetHeight):
    if (mirrorUser.listenHistory.len - 1) <= (listenEndInd + increment):
      case mirrorService:
      of Service.listenBrainzService:
        discard lbClient.pageUser(mirrorUser, listenEndInd)
      of Service.lastFmService:
        discard fmClient.pageUser(mirrorUser, listenEndInd)
      discard db.storeUser(mirrorUsersDbStore, mirrorUser, storedMirrorUsers)
    else:
      listenEndInd += increment

proc renderListen(listen: Listen, nowPlaying = false): Vnode =
  ## Renders a `Listen` object.
  var id, recordingUrl, artistUrl: cstring
  if nowPlaying:
    id = cstring "now-playing"
  else:
    id = cstring $get listen.listenedAt

  result = buildHtml:
    li(id = id, class = "row listen"):
      tdiv(id = "listen-details"):
        if nowPlaying:
          img(src = "/assets/nowplaying.svg")
        else:
          if isSome listen.mirrored:
            if get listen.mirrored:
              img(src = "/assets/mirrored.svg")
            else:
              img(src = "/assets/pre-mirror.svg")
        tdiv(id = "track-details"):
          p(title = listen.trackName, id = "track-name"):
            if isSome listen.recordingMbid:
              recordingUrl = "https://musicbrainz.org/recording/" & get listen.recordingMbid
              a(class = "track-metadata", href = recordingUrl):
                text listen.trackName
            else:
              text listen.trackName
          p(title = listen.artistName, id = "artist-name"):
            if isSome listen.artistMbids:
              artistUrl = "https://musicbrainz.org/artist/" & get(listen.artistMbids)[0]
              a(class = "track-metadata", href = artistUrl):
                text listen.artistName
            else:
              text listen.artistName
        if nowPlaying:
          span:
            text "Playing now"
        else:
          let listenTime = fromUnix get listen.listenedAt
          span(title = cstring listenTime.format("HH:mm:ss dd/MM/yy")):
            text listenTime.format("HH:mm")

proc renderListens*(playingNow: Option[Listen], listenHistory: seq[Listen], endInd: int): Vnode =
  ## Renders listen history.
  let dateFormat = "ddd d MMMM YYYY"
  var
    preMirrorSplit: bool = false
    lastCleanDate, cleanDate, today: string
    listenTime: Time

  result = buildHtml(tdiv(class = "listens", onscroll = pageListens)):
    ul:
      if isSome playingNow:
        renderListen(get playingNow, true)

      if listenHistory.len > 0:
        for idx, listen in listenHistory[0..endInd]:
          today = getTime().format(dateFormat)
          listenTime = fromUnix get listenHistory[idx].listenedAt
          cleanDate = listenTime.format(dateFormat)

          if isSome listen.preMirror:
            if get(listen.preMirror) and not preMirrorSplit:
              if idx == 0:
                preMirrorSplit = true
              else:
                tdiv(class = "mirror-bar"):
                  hr()
                  p:
                    text "Mirroring..."
                  hr()
                preMirrorSplit = true

          if today != cleanDate:
            if idx != 0:
              lastCleanDate = fromUnix(get listenHistory[idx - 1].listenedAt).format(dateFormat)
            if idx == 0 or (lastCleanDate != "" and lastCleanDate != cleanDate):
              tdiv(class = "listen-date"):
                p:
                  text cleanDate
                hr()

          renderListen listen

proc timeToUpdate(lastUpdateTs, ms: int): bool =
  ## Returns true if it is time to update the user again.
  let
    currentTs = int toUnix getTime()
    nextUpdateTs = lastUpdateTs + (ms div 1000)
  if currentTs >= nextUpdateTs: return true

proc setTimeoutAsync(ms: int): Future[void] =
  let promise = newPromise() do (res: proc(): void):
    discard setTimeout(res, ms)
  return promise

proc longPoll(service: Service, ms: int = 60000) {.async.} =
  ## Updates the mirrorUser every 60 seconds and stores to the database
  if not polling:
    polling = true
  await setTimeoutAsync(ms)
  if timeToUpdate(mirrorUser.lastUpdateTs, ms):
    log "Updating and submitting..."
    let preMirror = not mirrorToggle
    case service:
    of Service.listenBrainzService:
      mirrorUser = await lbClient.updateUser(mirrorUser, preMirror = preMirror)
      if mirrorToggle:
        discard lbClient.submitMirrorQueue(mirrorUser)
    of Service.lastFmService:
      mirrorUser = await fmClient.updateUser(mirrorUser, preMirror = preMirror)
      if mirrorToggle:
        discard fmClient.submitMirrorQueue(mirrorUser)
    discard db.storeUser(mirrorUsersDbStore, mirrorUser, storedMirrorUsers)
  discard longPoll(service, ms)

proc mirrorSwitch: Vnode =
  result = buildHtml(tdiv(id = "mirror-toggle")):
    p:
      text "Toggle mirroring: "
    label(class = "switch"):
      input(`type` = "checkbox", id = "mirror-switch", class = "toggle", checked = toChecked(mirrorToggle)):
        proc onclick(ev: kdom.Event; n: VNode) =
          if mirrorUser.services[mirrorService].username == clientUser.services[clientService].username:
            if not mirrorToggle:
              if window.confirm("Are you sure you want to mirror your own listens?"):
                mirrorToggle = true
              else:
                getElementById("mirror-switch").checked = mirrorToggle
            redraw()
          else:
            mirrorToggle = not mirrorToggle
      span(id = "mirror-slider", class = "slider")

proc mirror*: Vnode =
  var username, userUrl: cstring

  if not mirrorUser.isNil:
    if not clientUser.isNil:
      if clientUser.userId == mirrorUser.userId:
        mirrorToggle = false
      mirrorMirrorView = MirrorView.mirroring
    case mirrorService:
    of Service.listenBrainzService:
      username = mirrorUser.services[mirrorService].username
      userUrl = lb.userBaseUrl & username
    of Service.lastFmService:
      username = mirrorUser.services[mirrorService].username
      userUrl = lfm.userBaseUrl & username

  result = buildHtml(tdiv(id = "mirror-container")):
    tdiv(id = "mirror"):
      p:
        text "You are mirroring "
        a(href = userUrl):
          text $username & "!"
      mirrorSwitch()
    main:
      case mirrorMirrorView:
      of MirrorView.login:
        signinModal(mirrorSigninView, mirrorServiceView, mirrorModal = false)
      of MirrorView.mirroring:
        if not polling:
          discard longPoll(mirrorService)
        renderListens(mirrorUser.playingNow, mirrorUser.listenHistory, listenEndInd)

proc getMirrorUser(username: string, service: Service) {.async.} =
  ## Gets the mirror user from the database, if they aren't in the database, they are initialised
  storedMirrorUsers = await db.getUsers(mirrorUsersDbStore)
  let userId = cstring $service & ":" & username
  if userId in storedMirrorUsers:
    mirrorUser = storedMirrorUsers[userId]
    mirrorService = service
    let preMirror = not mirrorToggle
    case mirrorService:
    of Service.listenBrainzService:
      mirrorUser = await lbClient.updateUser(mirrorUser, resetLastUpdate = true, preMirror = preMirror)
    of Service.lastFmService:
      mirrorUser = await fmClient.updateUser(mirrorUser, resetLastUpdate = true, preMirror = preMirror)
    discard db.storeUser(mirrorUsersDbStore, mirrorUser, storedMirrorUsers)
    mirrorMirrorView = MirrorView.login
    globalView = ClientView.mirrorView
  else:
    try:
      case service:
      of Service.listenBrainzService:
        mirrorUser = await lbClient.initUser(username)
      of Service.lastFmService:
        mirrorUser = await fmClient.initUser(username)
      mirrorService = service
      discard db.storeUser(mirrorUsersDbStore, mirrorUser, storedMirrorUsers)
      mirrorMirrorView = MirrorView.login
      globalView = ClientView.mirrorView
    except JsonError:
      mirrorErrorMessage = "There was an error parsing this user's listens!"
      globalView = ClientView.errorView
    except:
      mirrorErrorMessage = "The requested user is not valid!"
      globalView = ClientView.errorView
  redraw()

proc mirrorRoute* =
  ## Routes the user to the mirror view.
  let path = $window.location.search
  if path != "":
    var params: Table[string, string]
    params = toTable toSeq decodeQuery(path.split("?")[1])
    if params.len != 0:
      if "username" in params and "service" in params:
        try:
          mirrorUsername = params["username"]
          mirrorService = parseEnum[Service]($params["service"])
          if mirrorUser.isNil and globalView != ClientView.errorView:
            globalView = ClientView.loadingView
            discard getMirrorUser(mirrorUsername, mirrorService)
          else:
            globalView = ClientView.mirrorView
        except ValueError:
          mirrorErrorMessage = "Invalid service!"
          globalView = ClientView.errorView
      else:
        mirrorErrorMessage = "Invalid parameters supplied! Links must include both service and user parameters!"
        globalView = ClientView.errorView
  else:
    mirrorErrorMessage = "No parameters supplied! Links must include both service and user parameters!"
    globalView = ClientView.errorView
