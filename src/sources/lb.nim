when defined(js):
  import std/asyncjs
else:
  import
    std/asyncdispatch

import
  pkg/listenbrainz,
  pkg/listenbrainz/utils/api,
  pkg/listenbrainz/core,
  ../types

include pkg/listenbrainz/utils/tools

const userBaseUrl* = "https://listenbrainz.org/user/"

proc to*(val: Option[seq[cstring]]): Option[seq[string]] =
  ## Convert `Option[seq[cstring]]` to `Option[seq[string]]`
  for item in val.get():
    result.get().add $item

proc to*(val: Option[seq[string]]): Option[seq[cstring]] =
  ## Convert `Option[seq[string]]` to `Option[seq[cstring]]`
  for item in val.get():
    result.get().add cstring item

proc to*(
  track: Track,
  listenedAt: Option[int]): APIListen =
  ## Convert a `Track` object to a `Listen` object
  let
    additionalInfo = AdditionalInfo(tracknumber: track.trackNumber,
                                    trackMbid: some $track.recordingMbid,
                                    recordingMbid: some $track.recordingMbid,
                                    releaseMbid: some $track.releaseMbid,
                                    artistMbids: to track.artistMbids)
    trackMetadata = TrackMetadata(trackName: $track.trackName,
                                  artistName: $track.artistName,
                                  releaseName: some $track.releaseName,
                                  additionalInfo: some additionalInfo)
  result = APIListen(listenedAt: listenedAt,
                     trackMetadata: trackMetadata)

proc to*(
  listen: APIListen,
  preMirror: Option[bool] = none(bool)): Track =
  ## Convert a `Listen` object to a `Track` object
  result = newTrack(trackName = cstring listen.trackMetadata.trackName,
                    artistName = cstring listen.trackMetadata.artistName,
                    releaseName = some cstring get listen.trackMetadata.releaseName,
                    recordingMbid = some cstring get get(listen.trackMetadata.additionalInfo).recordingMbid,
                    releaseMbid = some cstring get get(listen.trackMetadata.additionalInfo).releaseMbid,
                    artistMbids = to get(listen.trackMetadata.additionalInfo).artistMbids,
                    trackNumber = get(listen.trackMetadata.additionalInfo).trackNumber,
                    listenedAt = listen.listenedAt,
                    preMirror = preMirror,
                    mirrored = some false)

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


proc getRecentTracks*(
  lb: AsyncListenBrainz,
  user: User,
  preMirror: bool,
  count: int = 8): Future[seq[Track]] {.async.} =
  ## Return a ListenBrainz user's listen history
  let
    userListens = await lb.getUserListens($user.services[listenBrainzService].username, count = count)
  if userListens.payload.count > 0:
    result = to(userListens.payload.listens, some(preMirror))

# index history by listenedAt
# on init: get now playing and history set tracks as premirror
# on update: get listens, add to history if greater than latestListenTS, set as mirrored only when submitted succesfully

# def submitMirrorQueue*
