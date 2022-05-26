import
  std/[dom, times, options, asyncjs, sequtils, strutils, uri, tables],
  pkg/karax/[karax, karaxdsl, vdom, jstrutils],
  pkg/jsony,
  sources/[lb, lfm, utils],
  home, share, types

type
  MirrorView = enum
    login, mirroring

var
  mirrorView = MirrorView.login
  listenEndInd: int = 10
  mirrorToggle = true
  polling = false
  clientUserIds: seq[cstring]

proc pageListens(ev: Event; n: VNode) =
  ## Backfills the user's listens on scroll event and stores to DB
  let
    increment = 10
    d = n.dom

  if d != nil and ((d.scrollHeight - d.scrollTop) == d.offsetHeight):
    if (mirrorUsers[mirrorUserId].listenHistory.len - 1) <= (listenEndInd + increment):
      case mirrorUsers[mirrorUserId].service:
      of Service.listenBrainzService:
        discard lbClient.pageUser(mirrorUsers[mirrorUserId], listenEndInd)
      of Service.lastFmService:
        discard fmClient.pageUser(mirrorUsers[mirrorUserId], listenEndInd)
      discard db.storeUser(mirrorUsers[mirrorUserId], mirrorUsers, mirrorUsersDbStore)
    else:
      listenEndInd += increment

proc renderListen(listen: Listen, nowPlaying = false): Vnode =
  ## Renders a `Listen` object.
  var id: cstring
  if nowPlaying:
    id = "now-playing"
  else:
    id = & get listen.listenedAt

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
              a(class = "track-metadata", href = "https://musicbrainz.org/recording/" & get listen.recordingMbid):
                text listen.trackName
            else:
              text listen.trackName
          p(title = listen.artistName, id = "artist-name"):
            if isSome listen.artistMbids:
              a(class = "track-metadata", href = "https://musicbrainz.org/artist/" & get(listen.artistMbids)[0]):
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

proc longPoll(ms: int = 60000) {.async.} =
  ## Updates the mirror user every 60 seconds and stores to the database
  if globalView == ClientView.mirrorView:
    if not polling:
      polling = true
    if timeToUpdate(mirrorUsers[mirrorUserId].lastUpdateTs, ms):
      log "Updating and submitting..."
      let preMirror = not mirrorToggle
      case mirrorUsers[mirrorUserId].service:
      of Service.listenBrainzService:
        mirrorUsers[mirrorUserId] = await lbClient.updateUser(mirrorUsers[mirrorUserId], preMirror = preMirror)
        if mirrorToggle:
          discard lbClient.submitMirrorQueue(mirrorUsers[mirrorUserId])
      of Service.lastFmService:
        mirrorUsers[mirrorUserId] = await fmClient.updateUser(mirrorUsers[mirrorUserId], preMirror = preMirror)
        if mirrorToggle:
          discard fmClient.submitMirrorQueue(mirrorUsers[mirrorUserId])
      discard db.storeUser(mirrorUsers[mirrorUserId], mirrorUsers, mirrorUsersDbStore)
    await setTimeoutAsync(ms)
    discard longPoll(ms)

proc mirrorSwitch: Vnode =
  result = buildHtml(tdiv(id = "mirror-toggle")):
    p:
      text "Toggle mirroring: "
    label(class = "switch"):
      input(`type` = "checkbox", id = "mirror-switch", class = "toggle", checked = toChecked(mirrorToggle)):
        proc onclick(ev: Event; n: VNode) =
          if mirrorUsers[mirrorUserId].username in clientUserIds:
            if not mirrorToggle:
              if window.confirm("Are you sure you want to mirror your own listens?"):
                mirrorToggle = true
              else:
                getElementById("mirror-switch").checked = mirrorToggle
            redraw()
          else:
            mirrorToggle = not mirrorToggle
      span(id = "mirror-slider", class = "slider")

proc mirror*(username: cstring, service: Service): Vnode =
  var userUrl: cstring = ""
  if mirrorUsers.hasKey(mirrorUserId):
    clientUserIds = getSelectedIds(clientUsers)
    if clientUserIds.len > 0:
      if mirrorUsers[mirrorUserId].userId in clientUserIds:
        mirrorToggle = false
      mirrorView = MirrorView.mirroring
    case mirrorUsers[mirrorUserId].service:
    of Service.listenBrainzService:
      userUrl = lb.userBaseUrl & username
    of Service.lastFmService:
      userUrl = lfm.userBaseUrl & username

  result = buildHtml(tdiv(id = "mirror-container")):
    tdiv(id = "mirror"):
      p:
        text "You are mirroring "
        a(href = userUrl):
          text username & "!"
      mirrorSwitch()
    main:
      case mirrorView:
      of MirrorView.login:
        onboardModal(mirrorModal = false)
      of MirrorView.mirroring:
        if not polling:
          discard longPoll()
        renderListens(mirrorUsers[mirrorUserId].playingNow, mirrorUsers[mirrorUserId].listenHistory, listenEndInd)

proc getMirrorUser(username: cstring, service: Service) {.async.} =
  ## Gets the mirror user from the database, if they aren't in the database, they are initialised
  mirrorUsers = await db.getUsers(mirrorUsersDbStore)
  let userId: cstring = cstring($service) & ":" & username
  if userId in mirrorUsers:
    mirrorUsers[mirrorUserId] = mirrorUsers[userId]
    let preMirror = not mirrorToggle
    case mirrorUsers[mirrorUserId].service:
    of Service.listenBrainzService:
      mirrorUsers[mirrorUserId] = await lbClient.updateUser(mirrorUsers[mirrorUserId], resetLastUpdate = true, preMirror = preMirror)
    of Service.lastFmService:
      mirrorUsers[mirrorUserId] = await fmClient.updateUser(mirrorUsers[mirrorUserId], resetLastUpdate = true, preMirror = preMirror)
    discard db.storeUser(mirrorUsers[mirrorUserId], mirrorUsers, mirrorUsersDbStore)
    mirrorView = MirrorView.login
    globalView = ClientView.mirrorView
  else:
    try:
      case service:
      of Service.listenBrainzService:
        mirrorUsers[mirrorUserId] = await lbClient.initUser(username)
      of Service.lastFmService:
        mirrorUsers[mirrorUserId] = await fmClient.initUser(username)
      discard db.storeUser(mirrorUsers[mirrorUserId], mirrorUsers, mirrorUsersDbStore)
      mirrorView = MirrorView.login
      globalView = ClientView.mirrorView
    except JsonError:
      mirrorErrorMessage = "There was an error parsing this user's listens!"
      globalView = ClientView.errorView
    except:
      mirrorErrorMessage = "The requested user is not valid!"
      globalView = ClientView.errorView
  redraw()

proc mirrorRoute*: (cstring, Service) =
  ## Routes the user to the mirror view.
  let path = $window.location.search
  if path != "":
    var params: Table[string, string]
    params = toTable toSeq decodeQuery(path.split("?")[1])
    if params.len != 0:
      if "username" in params and "service" in params:
        try:
          let
            mirrorUsername = cstring params["username"]
            mirrorService = parseEnum[Service]($params["service"])
          result = (mirrorUsername, mirrorService)
          if not mirrorUsers.hasKey(mirrorUserId) and globalView != ClientView.errorView:
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
