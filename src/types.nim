import std/[options, times]


type
  Service* = enum
    listenBrainzService = "listenbrainz",
    lastFmService = "lastfm"

  ServiceUser* = object
    username*: cstring
    case service*: Service
    of listenBrainzService:
      token*: cstring
    of lastFmService:
      sessionKey*: cstring

  User* = object
    userId*: cstring
    services*: array[Service, ServiceUser]
    playingNow*: Option[Listen]
    listenHistory*: seq[Listen]
    lastUpdateTs*: int

  Listen* = object
    trackName*, artistName*: cstring
    releaseName*, recordingMbid*, releaseMbid*: Option[cstring]
    artistMbids*: Option[seq[cstring]]
    trackNumber*, listenedAt*: Option[int]
    mirrored*, preMirror*: Option[bool]


func newServiceUser*(
  service: Service,
  username, token, sessionKey: cstring = ""): ServiceUser =
  ## Create a new ServiceUser object
  result = ServiceUser(service: service)
  result.username = username
  case service:
  of listenBrainzService:
    result.token = token
  of lastFmService:
    result.sessionKey = sessionKey


func newUser*(
  userId: cstring = $toUnix(getTime()),
  services: array[Service, ServiceUser] = [listenBrainzService: newServiceUser(listenBrainzService), lastFmService: newServiceUser(lastFmService)],
  playingNow: Option[Listen] = none(Listen),
  listenHistory: seq[Listen] = @[],
  lastUpdateTs: int = 0): User =
  ## Create new User object
  result.userId = userId
  result.services = services
  result.playingNow = playingNow
  result.listenHistory = listenHistory
  result.lastUpdateTs = lastUpdateTs


func newListen*(
  trackName, artistName: cstring,
  releaseName, recordingMbid, releaseMbid: Option[cstring] = none(cstring),
  artistMbids: Option[seq[cstring]] = none(seq[cstring]),
  trackNumber: Option[int] = none(int),
  listenedAt: Option[int] = none(int),
  mirrored, preMirror: Option[bool] = none(bool)): Listen =
  ## Create new Listen object
  result.trackName = trackName
  result.artistName = artistName
  result.releaseName = releaseName
  result.recordingMbid = recordingMbid
  result.releaseMbid = releaseMbid
  result.artistMbids = artistMbids
  result.trackNumber = trackNumber
  result.listenedAt = listenedAt
  result.mirrored = mirrored
  result.preMirror = preMirror

func `==`*(a, b: Listen): bool =
  ## does not include `mirrored` or `preMirror`
  return a.trackName == b.trackName and
    a.artistName == b.artistName and
    a.releaseName == b.releaseName and
    a.artistMbids == b.artistMbids and
    a.trackNumber == b.trackNumber
