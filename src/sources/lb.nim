when defined(js):
  import std/asyncjs
else:
  import
    std/asyncdispatch,
    ../models

import
  pkg/listenbrainz,
  pkg/listenbrainz/utils/api,
  pkg/listenbrainz/core,
  ../types

include pkg/listenbrainz/utils/tools

proc to*(
  track: Track,
  listenedAt: Option[int]): APIListen =
  ## Convert a `Track` object to a `Listen` object
  let
    additionalInfo = AdditionalInfo(tracknumber: track.trackNumber,
                                    trackMbid: track.recordingMbid,
                                    recordingMbid: track.recordingMbid,
                                    releaseMbid: track.releaseMbid,
                                    artistMbids: track.artistMbids)
    trackMetadata = TrackMetadata(trackName: track.trackName,
                                  artistName: track.artistName,
                                  releaseName: track.releaseName,
                                  additionalInfo: some(additionalInfo))
  result = APIListen(listenedAt: listenedAt,
                     trackMetadata: trackMetadata)

proc to*(
  listen: APIListen,
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
  listens: seq[APIListen],
  preMirror: Option[bool] = none(bool)): seq[Track] =
  ## Convert a sequence of `Listen` objects to a sequence of `Track` objects
  for listen in listens:
    result.add(to(listen, preMirror))

proc to*(
  userListens: UserListens,
  listenType: ListenType): SubmitListens =
  ## Convert a `UserListens` object to a `SubmitListens` object
  result = SubmitListens(listenType: listenType, payload: userListens.payload.listens)

proc validateLbToken*(
  lb: AsyncListenBrainz,
  lbToken: string): Future[bool] {.async.} =
  ## Validate a ListenBrainz token given a ListenBrainz object and token
  let req = await lb.validateToken(lbToken)
  result = req.valid

proc getNowPlaying*(
  lb: AsyncListenBrainz,
  user: User): Future[Option[Track]] {.async.} =
  ## Return a ListenBrainz user's now playing
  let
    nowPlaying = await lb.getUserPlayingNow(user.services[listenBrainzService].username)
    payload = nowPlaying.payload
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
    userListens = await lb.getUserListens(user.services[listenBrainzService].username, count = count)
  if userListens.payload.count > 0:
    result = to(userListens.payload.listens, some(preMirror))
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
