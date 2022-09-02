import std/options

type
  Client* = ref object
    ## Stores client state, including a `seq` of user IDs, and optionally a mirror user ID.
    id*: cstring
    users*: seq[cstring]
    mirror*: Option[cstring]

  Service* = enum
    listenBrainzService = "listenbrainz",
    lastFmService = "lastfm"

  User* = ref object
    id*, username*: cstring
    case service*: Service
    of listenBrainzService:
      token*: cstring
    of lastFmService:
      sessionKey*: cstring
    lastUpdateTs*: int
    selected*: bool
    playingNow*: Option[Listen]
    listenHistory*: seq[Listen]

  Listen* = object
    trackName*, artistName*: cstring
    releaseName*, recordingMbid*, releaseMbid*: Option[cstring]
    artistMbids*: Option[seq[cstring]]
    trackNumber*, listenedAt*: Option[int]
    mirrored*, preMirror*: Option[bool]

func newClient*(
  id: cstring = "session",
  users: seq[cstring] = @[],
  mirror: Option[cstring] = none(cstring)): Client =
  result = Client()
  result.id = id
  result.users = users
  result.mirror = mirror

func newUser*(
  username: cstring,
  service: Service,
  token, sessionKey: cstring = "",
  lastUpdateTs: int = 0,
  selected: bool = false,
  playingNow: Option[Listen] = none(Listen),
  listenHistory: seq[Listen] = @[]): User =
  ## Create new User object
  result = User(service: service)
  result.id = cstring($service & ":" & $username)
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

func `==`*(a, b: User): bool = a.id == b.id

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
