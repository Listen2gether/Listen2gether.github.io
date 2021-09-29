when defined(js):
  import std/asyncjs
else:
  import std/asyncdispatch
  import pkg/norm/sqlite
  import ../models

import std/[json, strutils]
import pkg/listenbrainz
import pkg/listenbrainz/core
import ../types
include utils


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
    trackName*, artistName*: string
    releaseName*: Option[string]
    additionalInfo*: Option[AdditionalInfo]

  AdditionalInfo* = object
    tracknumber*: Option[int]
    trackMbid*, recordingMbid*, releaseGroupMbid*, releaseMbid*, isrc*, spotifyId*, listeningFrom*: Option[string]
    tags*, artistMbids*, workMbids*: Option[seq[string]]


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
  releaseName: Option[string] = none(string),
  additionalInfo: Option[AdditionalInfo] = none(AdditionalInfo)): TrackMetadata =
  ## Create new TrackMetadata object
  result.trackName = trackName
  result.artistName = artistName
  result.releaseName = releaseName
  result.additionalInfo = additionalInfo


func newAdditionalInfo*(
  tracknumber: Option[int] = none(int),
  trackMbid, recordingMbid, releaseGroupMbid, releaseMbid, isrc, spotifyId, listeningFrom: Option[string] = none(string),
  tags, artistMbids, workMbids: Option[seq[string]] = none(seq[string])): AdditionalInfo =
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


proc to*(
  listen: Listen,
  preMirror: Option[bool] = none(bool)): Track =
  ## Convert a `Listen` object to a `Track` object
  result = newTrack(trackName = listen.trackMetadata.trackName,
                    artistName = listen.trackMetadata.artistName,
                    releaseName = listen.trackMetadata.releaseName,
                    recordingMbid = get(listen.trackMetadata.additionalInfo).recordingMbid,
                    releaseMbid = get(listen.trackMetadata.additionalInfo).releaseMbid,
                    artistMbids = get(listen.trackMetadata.additionalInfo).artistMbids,
                    trackNumber = get(listen.trackMetadata.additionalInfo).trackNumber,
                    listenedAt = listen.listenedAt,
                    preMirror = preMirror,
                    mirrored = some(false))


proc to*(
  listens: seq[Listen],
  preMirror: Option[bool] = none(bool)): seq[Track] =
  ## Convert a sequence of `Listen` objects to a sequence of `Track` objects
  for listen in listens:
    result.add(to(listen, preMirror))


proc to*(
  listenPayload: ListenPayload,
  listenType: string): SubmissionPayload =
  ## Convert a `ListenPayload` object to a `SubmissionPayload` object
  result = newSubmissionPayload(listenType, listenPayload.listens)


proc validateLbToken*(
  lb: AsyncListenBrainz,
  lbToken: string) {.async.} =
  ## Validate a ListenBrainz token given a ListenBrainz object and token
  if lbToken != "":
    let result = await lb.validateToken(lbToken)
    if result["code"].getInt != 200:
      raise newException(ValueError, "ERROR: Invalid token (or perhaps you are rate limited)")
  else:
    raise newException(ValueError, "ERROR: Token is empty string.")


proc getNowPlaying*(
  lb: AsyncListenBrainz,
  user: User): Future[Option[Track]] {.async.} =
  ## Return a ListenBrainz user's now playing
  let
    nowPlaying = await lb.getUserPlayingNow(user.services[listenBrainzService].username)
    payload = fromJson($nowPlaying["payload"], ListenPayload)
  if payload.count == 1:
    result = some(to(payload.listens[0]))
  else:
    result = none(Track)


proc getRecentTracks*(
  lb: AsyncListenBrainz,
  user: User,
  preMirror: bool,
  count: int = 8): Future[seq[Track]] {.async.} =
  ## Return a ListenBrainz user's listen history
  let
    recentListens = await lb.getUserListens(user.services[listenBrainzService].username, count = count)
    payload = fromJson($recentListens["payload"], ListenPayload)
  if payload.count > 0:
    result = to(payload.listens, some(preMirror))
  else:
    result = @[]


proc updateUser*(
  lb: AsyncListenBrainz,
  user: User,
  preMirror: bool) {.async.} =
  ## Get a ListenBrainz user's `playingNow` and `listenHistory`
  user.playingNow = waitFor getNowPlaying(lb, user)
  user.listenHistory = waitFor getRecentTracks(lb, user, preMirror)
  updateUserTable(user, listenBrainzService)


# index history by listenedAt
# on init: get now playing and history set tracks as premirror
# on update: get listens, add to history if greater than latestListenTS, set as mirrored only when submitted succesfully

# def submitMirrorQueue*


proc listenTrack*(
  lb: AsyncListenBrainz,
  listenPayload: ListenPayload,
  listenType: string): Future[JsonNode] {.async.} =
  ## Submit a listen to ListenBrainz
  let
    payload = to(listenPayload, listenType)
    jsonBody = parseJson(payload.toJson())
  result = await lb.submitListens(jsonBody)
