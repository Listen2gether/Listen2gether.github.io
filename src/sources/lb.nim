import asyncdispatch, options, json, strutils
include listenbrainz
include utils
import ../types


type
  SubmissionPayload* = ref object
    listenType*: string
    payload*: seq[Listen]

  ListenPayload* = ref object
    count*: int
    latestListenTs*: Option[int64]
    listens*: seq[Listen]
    playingNow*: Option[bool]
    userId*: string

  Listen* = ref object
    listenedAt*: Option[int64]
    trackMetadata*: TrackMetadata
  
  TrackMetadata* = ref object
    trackName*, artistName*: string
    releaseName*: Option[string]
    additionalInfo*: Option[AdditionalInfo]
  
  AdditionalInfo* = ref object
    tracknumber*: Option[int]
    trackMbid*, recordingMbid*, releaseGroupMbid*, releaseMbid*, isrc*, spotifyId*, listeningFrom*: Option[string]
    tags*, artistMbids*, workMbids*: Option[seq[string]]


func newSubmissionPayload*(
  listenType: string,
  payload: seq[Listen]): SubmissionPayload =
  ## Create new SubmissionPayload object
  new(result)
  result.listenType = listenType
  result.payload = payload


func newListenPayload*(
  count: int,
  latestListenTs: Option[int64] = none(int64),
  listens: seq[Listen],
  playingNow: Option[bool] = none(bool),
  userId: string): ListenPayload =
  ## Create new ListenPayload object
  new(result)
  result.count = count
  result.latestListenTs = latestListenTs
  result.listens = listens
  result.playingNow = playingNow
  result.userId = userId


func newListen*(
  listenedAt: Option[int64] = none(int64),
  trackMetadata: TrackMetadata): Listen =
  ## Create new Listen object
  new(result)
  result.listenedAt = listenedAt
  result.trackMetadata = trackMetadata


func newTrackMetadata*(
  trackName, artistName: string,
  releaseName: Option[string] = none(string),
  additionalInfo: Option[AdditionalInfo] = none(AdditionalInfo)): TrackMetadata =
  ## Create new TrackMetadata object
  new(result)
  result.trackName = trackName
  result.artistName = artistName
  result.releaseName = releaseName
  result.additionalInfo = additionalInfo


func newAdditionalInfo*(
  tracknumber: Option[int] = none(int),
  trackMbid, recordingMbid, releaseGroupMbid, releaseMbid, isrc, spotifyId, listeningFrom: Option[string] = none(string),
  tags, artistMbids, workMbids: Option[seq[string]] = none(seq[string])): AdditionalInfo =
  ## Create new Track object
  new(result)
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


proc to*(
  track: Track,
  listenedAt: Option[int64]): Listen = 
  ## Convert a `Track` object to a `Listen` object
  let
    additionalInfo = newAdditionalInfo(tracknumber = track.trackNumber,
                                       trackMbid = track.recordingMbid,
                                       recordingMbid = track.recordingMbid,
                                       releaseMbid = track.releaseMbid,
                                       artistMbids = track.artistMbids)
    trackMetadata = newTrackMetadata(trackName = track.trackName,
                                     artistName = track.artistName,
                                     releaseName = track.releaseName,
                                     additionalInfo = some(additionalInfo))
  result = newListen(listenedAt = listenedAt,
                     trackMetadata = trackMetadata)


proc to*(listen: Listen): Track =
  ## Convert a `Listen` object to a `Track` object
  result = newTrack(trackName = listen.trackMetadata.trackName,
                    artistName = listen.trackMetadata.artistName,
                    releaseName = listen.trackMetadata.releaseName,
                    recordingMbid = get(listen.trackMetadata.additionalInfo).recordingMbid,
                    releaseMbid = get(listen.trackMetadata.additionalInfo).releaseMbid,
                    artistMbids = get(listen.trackMetadata.additionalInfo).artistMbids,
                    trackNumber = get(listen.trackMetadata.additionalInfo).trackNumber)


proc to*(
  listenPayload: ListenPayload,
  listenType: string): SubmissionPayload =
  ## Convert a `ListenPayload` object to a `SubmissionPayload` object
  result = newSubmissionPayload(listenType, listenPayload.listens)


proc validateLbToken*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  lbToken: string) {.multisync.} =
  ## Validate a ListenBrainz token given a ListenBrainz object and token
  if lbToken != "":
    let result = await lb.validateToken(lbToken)
    if result["code"].getInt != 200:
      raise newException(ValueError, "ERROR: Invalid token (or perhaps you are rate limited)")
  else:
    raise newException(ValueError, "ERROR: Token is empty string.")


proc getNowPlaying*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  user: User) {.multisync.} =
  ## Get a ListenBrainz user's now playing
  let
    nowPlaying = await lb.getUserPlayingNow(user.username)
    listen = fromJson($nowPlaying["payload"], ListenPayload)
  if listen.listens != @[]:
    user.playingNow = some(to(listen.listens[0]))


proc getCurrentTrack*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  user: User): Future[ListenPayload] {.multisync.} =
  ## Get a user's last listened track
  let recentListens = await lb.getUserListens(user.userName, count=1)
  result = fromJson($recentListens["payload"], ListenPayload)  
  if result.count == 0:
    user.lastPlayed = none(Track)
    raise newException(ValueError, "ERROR: User has no recent listens!")
  else:
    user.lastPlayed = some(to(result.listens[0]))

proc listenTrack*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  listenPayload: ListenPayload,
  listenType: string): Future[JsonNode] {.multisync.} =
  ## Submit a listen to ListenBrainz
  let
    payload = to(listenPayload, listenType)
    jsonBody = parseJson(payload.toJson())
  result = await lb.submitListens(jsonBody)