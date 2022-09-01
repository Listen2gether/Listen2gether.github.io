import std/options

type
  Service* = enum
    listenBrainzService = "listenbrainz",
    lastFmService = "lastfm"

  ListenQueue* = ref object
    listens*: seq[Listen]
    playingNow*: Option[Listen]

  User* = ref object
    userId*, username*: cstring
    case service*: Service
    of listenBrainzService:
      token*: cstring
    of lastFmService:
      sessionKey*: cstring
    lastUpdateTs*: int
    selected*: bool
    playingNow*: Option[Listen]
    listenHistory*: seq[Listen]
    submitQueue*: ListenQueue

  Listen* = object
    trackName*, artistName*: cstring
    releaseName*, recordingMbid*, releaseMbid*: Option[cstring]
    artistMbids*: Option[seq[cstring]]
    trackNumber*, listenedAt*: Option[int]
    playingNow*: Option[bool]

func newListenQueue*(
  listens: seq[Listen] = @[],
  playingNow: Option[Listen] = none(Listen)): ListenQueue =
  result = ListenQueue()
  result.listens = listens
  result.playingNow = playingNow

func newUser*(
  username: cstring,
  service: Service,
  token, sessionKey: cstring = "",
  lastUpdateTs: int = 0,
  selected: bool = false,
  playingNow: Option[Listen] = none(Listen),
  listenHistory: seq[Listen] = @[],
  submitQueue: ListenQueue = newListenQueue()): User =
  ## Create new User object
  result = User(service: service)
  result.userId = cstring($service & ":" & $username)
  result.username = username
  case service:
  of listenBrainzService:
    result.token = token
  of lastFmService:
    result.sessionKey = sessionKey
  result.lastUpdateTs = lastUpdateTs
  result.selected = selected
  result.playingNow = playingNow
  result.listenHistory = listenHistory
  result.submitQueue = submitQueue

func `==`*(a, b: User): bool = a.userId == b.userId

func newListen*(
  trackName, artistName: cstring,
  releaseName, recordingMbid, releaseMbid: Option[cstring] = none(cstring),
  artistMbids: Option[seq[cstring]] = none(seq[cstring]),
  trackNumber: Option[int] = none(int),
  listenedAt: Option[int] = none(int),
  playingNow: Option[bool] = none(bool)): Listen =
  ## Create new Listen object
  result.trackName = trackName
  result.artistName = artistName
  result.releaseName = releaseName
  result.recordingMbid = recordingMbid
  result.releaseMbid = releaseMbid
  result.artistMbids = artistMbids
  result.trackNumber = trackNumber
  result.listenedAt = listenedAt
  result.playingNow = playingNow

func `==`*(a, b: Listen): bool =
  ## Does not consider `listenedAt` and `playingNow` fields.
  return a.trackName == b.trackName and
    a.artistName == b.artistName and
    a.releaseName == b.releaseName and
    a.recordingMbid == b.recordingMbid and
    a.releaseMbid == b.releaseMbid and
    a.artistMbids == b.artistMbids and
    a.trackNumber == b.trackNumber
