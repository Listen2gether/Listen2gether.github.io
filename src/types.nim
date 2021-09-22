import std/options


type
  Service* = enum
    listenBrainzService,
    lastFmService

  ServiceUser* = ref object
    username*, baseUrl*: string
    case service: Service
    of listenBrainzService:
      token*: string
    of lastFmService:
      sessionKey*: string

  User* = ref object
    services*: array[Service, ServiceUser]
    playingNow*: Option[Track]
    toMirror*, listenHistory*: seq[Track]

  Track* = object
    trackName*, artistName*: string
    releaseName*, recordingMbid*, releaseMbid*: Option[string]
    artistMbids*: Option[seq[string]]
    trackNumber*, duration*: Option[int]
    listenedAt*: Option[int64]


func newServiceUser*(
  service: Service,
  username, url, token, sessionKey: string = ""): ServiceUser =
  ## Create a new ServiceUser object
  result = ServiceUser(service: service)
  result.username = username
  case service:
  of listenBrainzService:
    result.baseUrl = "https://listenbrainz.org/user/"
    result.token = token
  of lastFmService:
    result.baseUrl = "https://last.fm/user/"
    result.sessionKey = sessionKey


func newUser*(
  services: array[Service, ServiceUser] = [listenBrainzService: newServiceUser(listenBrainzService), lastFmService: newServiceUser(lastFmService)],
  playingNow: Option[Track] = none(Track),
  toMirror, listenHistory: seq[Track] = @[]): User =
  ## Create new User object
  new(result)
  result.services = services
  result.playingNow = playingNow
  result.toMirror = toMirror
  result.listenHistory = listenHistory


func newTrack*(
  trackName, artistName: string,
  releaseName, recordingMbid, releaseMbid: Option[string] = none(string),
  artistMbids: Option[seq[string]] = none(seq[string]),
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
