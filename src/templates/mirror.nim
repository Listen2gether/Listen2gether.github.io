import
  std/[dom, times, options, asyncjs, tables],
  pkg/karax/[karax, karaxdsl, vdom],
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
  mirrorUserService: Service
  listenEndInd: int = 10

proc setTimeoutAsync(ms: int): Future[void] =
  let promise = newPromise() do (res: proc(): void):
    discard setTimeout(res, ms)
  return promise

proc timeToUpdate(lastUpdateTs: int, ms: int = 30000): bool =
  ## Returns true if it is time to update the user again.
  let nextUpdateTs = lastUpdateTs + (ms div 1000)
  if int(toUnix getTime()) >= nextUpdateTs: return true

proc longPoll(service: Service, ms: int = 30000) {.async.} =
  ## Updates the mirrorUser every 30 seconds and stores to the database
  await setTimeoutAsync(ms)
  if timeToUpdate(mirrorUser.lastUpdateTs, ms):
    case service:
    of Service.listenBrainzService:
      mirrorUser = await lbClient.updateUser(mirrorUser)
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
    if timeToUpdate(mirrorUser.lastUpdateTs):
      case service:
      of Service.listenBrainzService:
        mirrorUser = await lbClient.updateUser(mirrorUser)
      of Service.lastFmService:
        mirrorUser = nil
      discard db.storeUser(mirrorUsersDbStore, mirrorUser)
    mirrorMirrorView = MirrorView.login
    redraw()
  else:
    try:
      case service:
      of Service.listenBrainzService:
        mirrorUser = await lbClient.initUser(username)
      of Service.lastFmService:
        mirrorUser = nil
      discard db.storeUser(mirrorUsersDbStore, mirrorUser)
      mirrorMirrorView = MirrorView.login
      redraw()
    except HttpRequestError:
      mirrorErrorMessage = "The requested user is not valid!"
      globalView = ClientView.errorView
      redraw()

proc pageListens(ev: Event; n: VNode) =
  ## Backfills the user's listens on scroll event and stores to DB
  let d = n.dom
  if d != nil and inViewport(d.lastChild):
    if mirrorUser.listenHistory[0..listenEndInd].len > d.len:
      case mirrorUserService:
      of Service.listenBrainzService:
        discard lbClient.pageUser(mirrorUser)
      of Service.lastFmService:
        mirrorUser = nil
      discard db.storeUser(mirrorUsersDbStore, mirrorUser)
    else:
      listenEndInd += 10
      redraw()

proc renderListens*(playingNow: Option[Track], listenHistory: seq[Track], endInd: int): Vnode =
  var
    trackName, artistName: cstring
    preMirrorSplit: bool = false

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
            let
              date = cstring fromUnix(get track.listenedAt).format("HH:mm:ss dd/MM/yy")
              time = fromUnix(get track.listenedAt).format("HH:mm")
            if isSome track.preMirror:
              if get(track.preMirror) and not preMirrorSplit:
                if idx == 0:
                  preMirrorSplit = true
                else:
                  hr()
                  preMirrorSplit = true
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
                span(title = date):
                  text time

proc mirrorError*(message: string): Vnode =
  result = buildHtml:
    main:
      tdiv(id = "mirror-error"):
        errorMessage("Uh Oh!")
        errorMessage(message)

proc mainSection*(service: Service): Vnode =
  var username, userUrl: cstring
  mirrorUserService = service

  if mirrorUser.isNil:
    echo "mirror user is nil!"
  else:
    echo "mirror user is good :)"
    if not clientUser.isNil:
      mirrorMirrorView = MirrorView.mirroring
    case service:
    of Service.listenBrainzService:
      username = mirrorUser.services[Service.listenBrainzService].username
      userUrl = cstring(lb.userBaseUrl & $username)
    of Service.lastFmService:
      username = mirrorUser.services[Service.lastFmService].username
      # userUrl = lfm.userBaseUrl & username

  result = buildHtml:
    tdiv:
      case mirrorMirrorView:
      of MirrorView.login:
        signinCol(mirrorSigninView, mirrorServiceView, mirror = false)
      of MirrorView.mirroring:
        discard longPoll(service)
        tdiv(id = "mirror"):
          p:
            text "You are mirroring "
            a(href = userUrl):
              text $username & "!"
        renderListens(mirrorUser.playingNow, mirrorUser.listenHistory, listenEndInd)
