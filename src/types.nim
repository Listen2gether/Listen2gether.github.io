import std/[options, times]


type
  Service* = enum
    listenBrainzService = "listenbrainz",
    lastFmService = "lastfm"

  ServiceUser* = ref object
    username*: cstring
    case service*: Service
    of listenBrainzService:
      token*: cstring
    of lastFmService:
      sessionKey*: cstring

  User* = ref object
    userId*: cstring
    services*: array[Service, ServiceUser]
    playingNow*: Option[Track]
    listenHistory*: seq[Track]
    latestListenTs*: int

  Track* = object
    trackName*, artistName*: string
    releaseName*, recordingMbid*, releaseMbid*: Option[string]
    artistMbids*: Option[seq[string]]
    trackNumber*, duration*: Option[int]
    listenedAt*: Option[int]
    mirrored*, preMirror*: Option[bool]


func newServiceUser*(
  service: Service,
  username, token, sessionKey: string = ""): ServiceUser =
  ## Create a new ServiceUser object
  result = ServiceUser(service: service)
  result.username = username
  case service:
  of listenBrainzService:
    result.token = token
  of lastFmService:
    result.sessionKey = sessionKey


func newUser*(
  userId: string = $toUnix(getTime()),
  services: array[Service, ServiceUser] = [listenBrainzService: newServiceUser(listenBrainzService), lastFmService: newServiceUser(lastFmService)],
  playingNow: Option[Track] = none(Track),
  listenHistory: seq[Track] = @[]): User =
  ## Create new User object
  new(result)
  result.userId = userId
  result.services = services
  result.playingNow = playingNow
  result.listenHistory = listenHistory


func newTrack*(
  trackName, artistName: string,
  releaseName, recordingMbid, releaseMbid: Option[string] = none(string),
  artistMbids: Option[seq[string]] = none(seq[string]),
  trackNumber, duration: Option[int] = none(int),
  listenedAt: Option[int] = none(int),
  mirrored, preMirror: Option[bool] = none(bool)): Track =
  ## Create new Track object
  result.trackName = trackName
  result.artistName = artistName
  result.releaseName = releaseName
  result.recordingMbid = recordingMbid
  result.releaseMbid = releaseMbid
  result.artistMbids = artistMbids
  result.trackNumber = trackNumber
  result.duration = duration
  result.listenedAt = listenedAt
  result.mirrored = mirrored
  result.preMirror = preMirror
