import options

type
  User* = ref object
    username*: string
    lfmSessionKey*, lbToken*: Option[string]
    playingNow*, lastPlayed*: Option[Track]

  Track* = ref object
    trackName*, artistName*: string
    releaseName*, recordingMbid*, releaseMbid*: Option[string]
    artistMbids*: Option[seq[string]]
    trackNumber*, duration*: Option[int]


func newUser*(
  username: string,
  lfmSessionKey, lbToken: Option[string] = none(string),
  playingNow, lastPlayed: Option[Track] = none(Track)): User =
  ## Create new User object
  new(result)
  result.username = username
  result.lfmSessionKey = lfmSessionKey
  result.lbToken = lbToken
  result.playingNow = playingNow
  result.lastPlayed = lastPlayed


func newTrack*(
  trackName, artistName: string,
  releaseName, recordingMbid, releaseMbid: Option[string] = none(string),
  artistMbids: Option[seq[string]] = none(seq[string]),
  trackNumber, duration: Option[int] = none(int)): Track =
  ## Create new Track object
  new(result)
  result.trackName = trackName
  result.artistName = artistName
  result.releaseName = releaseName
  result.recordingMbid = recordingMbid
  result.releaseMbid = releaseMbid
  result.artistMbids = artistMbids
  result.trackNumber = trackNumber
  result.duration = duration
