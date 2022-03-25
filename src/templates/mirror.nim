import
  std/[dom, times, options, asyncjs, tables],
  pkg/karax/[karax, karaxdsl, vdom],
  pkg/simple_matrix_client/client,
  pkg/listenbrainz,
  ../sources/[lb],
  ../types, home, share

type
  MirrorView* = enum
    login, mirroring

var
  mirrorMirrorView = MirrorView.login
  mirrorSigninView = SigninView.loadingUsers
  mirrorServiceView = ServiceView.none
  listenEndInd: int = 10
  mirrorToggle: bool = true
  polling: bool = false

proc setTimeoutAsync(ms: int): Future[void] =
  let promise = newPromise() do (res: proc(): void):
    discard setTimeout(res, ms)
  return promise

proc timeToUpdate(lastUpdateTs, ms: int): bool =
  ## Returns true if it is time to update the user again.
  let
    currentTs = int(toUnix getTime())
    nextUpdateTs = lastUpdateTs + (ms div 1000)
  if currentTs >= nextUpdateTs: return true

proc longPoll(service: Service, ms: int = 60000) {.async.} =
  ## Updates the mirrorUser every 60 seconds and stores to the database
  if not polling:
    polling = true
  await setTimeoutAsync(ms)
  if timeToUpdate(mirrorUser.lastUpdateTs, ms):
    echo "Updating and submitting..."
    case service:
    of Service.listenBrainzService:
      let preMirror = not mirrorToggle
      mirrorUser = await lbClient.updateUser(mirrorUser, preMirror = preMirror)
      if mirrorToggle:
        discard lbClient.submitMirrorQueue(mirrorUser)
    of Service.lastFmService:
      mirrorUser = nil
    discard db.storeUser(mirrorUsersDbStore, mirrorUser)
  discard longPoll(service, ms)

proc getMirrorUser*(username: cstring, service: Service) {.async.} =
  ## Gets the mirror user from the database, if they aren't in the database, they are initialised
  storedMirrorUsers = await db.getUsers(mirrorUsersDbStore)
  let userId = cstring($service & ":" & $username)
  if userId in storedMirrorUsers:
    mirrorUser = storedMirrorUsers[userId]
    mirrorService = service
    case mirrorService:
    of Service.listenBrainzService:
      let preMirror = not mirrorToggle
      mirrorUser = await lbClient.updateUser(mirrorUser, resetLastUpdate = true, preMirror = preMirror)
    of Service.lastFmService:
      mirrorUser = nil
    discard db.storeUser(mirrorUsersDbStore, mirrorUser)
    mirrorMirrorView = MirrorView.login
    globalView = ClientView.mirrorView
    redraw()
  else:
    try:
      case service:
      of Service.listenBrainzService:
        mirrorUser = await lbClient.initUser(username)
        mirrorService = service
      of Service.lastFmService:
        mirrorUser = nil
      discard db.storeUser(mirrorUsersDbStore, mirrorUser)
      mirrorMirrorView = MirrorView.login
      globalView = ClientView.mirrorView
      redraw()
    except HttpRequestError:
      mirrorErrorMessage = "The requested user is not valid!"
      globalView = ClientView.errorView
      redraw()

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
        mirrorUser = nil
      discard db.storeUser(mirrorUsersDbStore, mirrorUser)
    else:
      listenEndInd += increment

proc renderListens*(playingNow: Option[Track], listenHistory: seq[Track], endInd: int): Vnode =
  let dateFormat = "ddd d MMMM YYYY"
  var
    trackName, artistName: cstring
    preMirrorSplit: bool = false
    lastCleanDate, cleanDate, today, time: string
    listenTime: Time
    detailedDate: cstring

  result = buildHtml:
    tdiv(class = "listens"):
      ul(onscroll = pageListens):
        if isSome playingNow:
          li(id = "now-playing", class = "row listen"):
            tdiv(id = "listen-details"):
              img(src = "/assets/nowplaying.svg")
              tdiv(id = "track-details"):
                trackName = get(playingNow).trackName
                artistName = get(playingNow).artistName
                p(title = trackName, id = "track-name"):
                  text trackName
                p(title = artistName, id = "artist-name"):
                  text artistName
              span:
                text "Playing now"

        if listenHistory.len > 0:
          for idx, track in listenHistory[0..endInd]:
            today = getTime().format(dateFormat)
            listenTime = fromUnix get listenHistory[idx].listenedAt
            cleanDate = listenTime.format(dateFormat)
            detailedDate = cstring listenTime.format("HH:mm:ss dd/MM/yy")
            time = listenTime.format("HH:mm")

            if isSome track.preMirror:
              if get(track.preMirror) and not preMirrorSplit:
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

            li(id = cstring($get(track.listenedAt)), class = "row listen"):
              tdiv(id = "listen-details"):
                if isSome track.mirrored:
                  if get track.mirrored:
                    img(src = "/assets/mirrored.svg")
                  else:
                    img(src = "/assets/pre-mirror.svg")
                tdiv(id = "track-details"):
                  trackName = track.trackName
                  artistName = track.artistName
                  p(title = trackName, id = "track-name"):
                    text trackName
                  p(title = artistName, id = "artist-name"):
                    text artistName
                span(title = detailedDate):
                  text time

proc mirrorError*(message: string): Vnode =
  result = buildHtml:
    main:
      tdiv(id = "mirror-error"):
        errorMessage("Uh Oh!")
        errorMessage(message)

proc mirrorSwitch: Vnode =
  result = buildHtml:
    tdiv(id = "mirror-toggle"):
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

proc mirror*(clientUserService, mirrorUserService: Service): Vnode =
  var username, userUrl: cstring

  if not mirrorUser.isNil:
    if not clientUser.isNil:
      if clientUser.services[clientService].username == mirrorUser.services[mirrorService].username:
        mirrorToggle = false
      mirrorMirrorView = MirrorView.mirroring
    case mirrorService:
    of Service.listenBrainzService:
      username = mirrorUser.services[mirrorService].username
      userUrl = cstring(lb.userBaseUrl & $username)
    of Service.lastFmService:
      username = mirrorUser.services[mirrorService].username
      # userUrl = lfm.userBaseUrl & username

  result = buildHtml:
    main:
      case mirrorMirrorView:
      of MirrorView.login:
        signinCol(mirrorSigninView, mirrorServiceView, mirror = false)
      of MirrorView.mirroring:
        if not polling:
          discard longPoll(mirrorUserService)
        tdiv(id = "mirror-container"):
          tdiv(id = "mirror"):
            p:
              text "You are mirroring "
              a(href = userUrl):
                text $username & "!"
            mirrorSwitch()
          renderListens(mirrorUser.playingNow, mirrorUser.listenHistory, listenEndInd)
