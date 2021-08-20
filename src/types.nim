import options


type
  Service* = enum
    listenBrainz,
    lastFm

  ServiceUser* = ref object
    username*: string
    case service: Service
    of listenBrainz:
      token*: string
    of lastFm:
      apiKey*, apiSecret*, sessionKey*: string

  User* = ref object
    services*: array[Service, ServiceUser]
    playingNow*: Option[Track]
    listenHistory*: seq[Track]

  Track* = object
    trackName*, artistName*, releaseName*, recordingMbid*, releaseMbid*: string
    artistMbids*: seq[string]
    trackNumber*, duration*: Option[int]


func newServiceUser*(
  service: Service,
  username: string,
  token, apiKey, apiSecret, sessionKey: string = ""): ServiceUser =
  ## Create a new ServiceUser object
  result = ServiceUser(service: service)
  result.username = username
  case service:
  of listenBrainz:
    result.token = token
  of lastFm:
    result.apiKey = apiKey
    result.apiSecret = apiSecret
    result.sessionKey = sessionKey


func newUser*(
  services: array[Service, ServiceUser],
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
  trackNumber, duration: Option[int] = none(int)): Track =
  ## Create new Track object
  result.trackName = trackName
  result.artistName = artistName
  result.releaseName = releaseName
  result.recordingMbid = recordingMbid
  result.releaseMbid = releaseMbid
  result.artistMbids = artistMbids
  result.trackNumber = trackNumber
  result.duration = duration
