import std/options

type
  SubmissionPayload* = object
    listenType*: string
    payload*: seq[Listen]

  ListenPayload* = object
    count*: int
    latestListenTs*: Option[int64]
    listens*: seq[Listen]
    playingNow*: Option[bool]

  Listen* = object
    listenedAt*: Option[int64]
    trackMetadata*: TrackMetadata

  TrackMetadata* = object
    trackName*, artistName*, releaseName*: string
    additionalInfo*: Option[AdditionalInfo]

  AdditionalInfo* = object
    tracknumber*: Option[int]
    trackMbid*, recordingMbid*, releaseGroupMbid*, releaseMbid*, isrc*, spotifyId*, listeningFrom*: string
    tags*, artistMbids*, workMbids*: seq[string]


func newSubmissionPayload*(
  listenType: string,
  payload: seq[Listen]): SubmissionPayload =
  ## Create new SubmissionPayload object
  result.listenType = listenType
  result.payload = payload


func newListenPayload*(
  count: int,
  latestListenTs: Option[int64] = none(int64),
  listens: seq[Listen],
  playingNow: Option[bool] = none(bool)): ListenPayload =
  ## Create new ListenPayload object
  result.count = count
  result.latestListenTs = latestListenTs
  result.listens = listens
  result.playingNow = playingNow


func newListen*(
  listenedAt: Option[int64] = none(int64),
  trackMetadata: TrackMetadata): Listen =
  ## Create new Listen object
  result.listenedAt = listenedAt
  result.trackMetadata = trackMetadata


func newTrackMetadata*(
  trackName, artistName: string,
  releaseName: string = "",
  additionalInfo: Option[AdditionalInfo] = none(AdditionalInfo)): TrackMetadata =
  ## Create new TrackMetadata object
  result.trackName = trackName
  result.artistName = artistName
  result.releaseName = releaseName
  result.additionalInfo = additionalInfo


func newAdditionalInfo*(
  tracknumber: Option[int] = none(int),
  trackMbid, recordingMbid, releaseGroupMbid, releaseMbid, isrc, spotifyId, listeningFrom: string = "",
  tags, artistMbids, workMbids: seq[string] = @[]): AdditionalInfo =
  ## Create new Track object
  result.tracknumber = tracknumber
  result.trackMbid = trackMbid
  result.recordingMbid = recordingMbid
  result.releaseGroupMbid = releaseGroupMbid
  result.releaseMbid = releaseMbid
  result.isrc = isrc
  result.spotifyId = spotifyId
  result.listeningFrom = listeningFrom
  result.tags = tags
  result.artistMbids = artistMbids
  result.workMbids = workMbids