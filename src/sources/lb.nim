when defined(js):
  import std/[asyncjs, json, strutils, jsconsole]
  import listenbrainz
  import listenbrainz/core
  include utils
  import ../types
else:
  import std/[asyncdispatch, json, strutils]
  import listenbrainz
  import listenbrainz/core
  include utils
  import ../types


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


proc parseHook*(s: string, i: var int, v: var int64) =
  var str: string
  parseHook(s, i, str)
  v = parseInt(str)


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
                    trackNumber = get(listen.trackMetadata.additionalInfo).trackNumber,
                    listenedAt = listen.listenedAt)


proc to*(listens: seq[Listen]): seq[Track] =
  ## Convert a sequence of `Listen` objects to a sequence of `Track` objects
  for listen in listens:
    result.add(to(listen))


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
  user: User): Future[Option[Track]] {.multisync.} =
  ## Return a ListenBrainz user's now playing
  let
    nowPlaying = await lb.getUserPlayingNow(user.services[listenBrainzService].username)
  when defined(js):
    console.log($nowPlaying["payload"])
  let payload = fromJson($nowPlaying["payload"], ListenPayload)
  if payload.count == 1:
    result = some(to(payload.listens[0]))
  else:
    result = none(Track)


proc getRecentTracks*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  user: User,
  count: int = 7): Future[seq[Track]] {.multisync.} =
  ## Return a ListenBrainz user's listen history
  var tracks: seq[Track]
  let
    recentListens = await lb.getUserListens(user.services[listenBrainzService].username, count = count)
    payload = fromJson($recentListens["payload"], ListenPayload)
  if payload.count > 0:
    result = to(payload.listens)
  else:
    result = tracks


proc updateUser*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  user: User) {.multisync.} =
  ## Update a ListenBrainz user's `playingNow` and `listenHistory`
  user.playingNow = await getNowPlaying(lb, user)
  user.listenHistory = await getRecentTracks(lb, user)


proc listenTrack*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  listenPayload: ListenPayload,
  listenType: string): Future[JsonNode] {.multisync.} =
  ## Submit a listen to ListenBrainz
  let
    payload = to(listenPayload, listenType)
    jsonBody = parseJson(payload.toJson())
  result = await lb.submitListens(jsonBody)