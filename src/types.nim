import std/options


type
  Service* = enum
    listenBrainzService,
    lastFmService

  ServiceUser* = ref object
    username*: string
    case service: Service
    of listenBrainzService:
      token*: string
    of lastFmService:
      sessionKey*: string

  User* = ref object
    services*: array[Service, ServiceUser]
    playingNow*: Option[Track]
    listenHistory*: seq[Track]

  Track* = object
    trackName*, artistName*, releaseName*, recordingMbid*, releaseMbid*: string
    artistMbids*: seq[string]
    trackNumber*, duration*: Option[int]
    listenedAt*: Option[int64]


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
  services: array[Service, ServiceUser] = [listenBrainzService: newServiceUser(listenBrainzService), lastFmService: newServiceUser(lastFmService)],
  playingNow: Option[Track] = none(Track),
  listenHistory: seq[Track] = @[]): User =
  ## Create new User object
  new(result)
  result.services = services
  result.playingNow = playingNow
  result.listenHistory = listenHistory


func newTrack*(
  trackName, artistName, releaseName, recordingMbid, releaseMbid: string = "",
  artistMbids: seq[string] = @[],
  trackNumber, duration: Option[int] = none(int),
  listenedAt: Option[int64] = none(int64)): Track =
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
