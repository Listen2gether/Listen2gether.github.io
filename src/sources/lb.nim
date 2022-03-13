when defined(js):
  import std/asyncjs
else:
  import
    std/asyncdispatch

import
  std/strutils,
  pkg/listenbrainz,
  pkg/listenbrainz/utils/api,
  pkg/listenbrainz/core,
  ../types

include pkg/listenbrainz/utils/tools

const userBaseUrl* = "https://listenbrainz.org/user/"

proc to*(val: Option[seq[cstring]]): Option[seq[string]] =
  ## Convert `Option[seq[cstring]]` to `Option[seq[string]]`
  if isSome val:
    for item in val.get():
      result.get().add $item
  else:
    result = none seq[string]

proc to*(val: Option[seq[string]]): Option[seq[cstring]] =
  ## Convert `Option[seq[string]]` to `Option[seq[cstring]]`
  if isSome val:
    for item in val.get():
      result.get().add cstring item
  else:
    result = none seq[cstring]

proc to*(val: Option[string]): Option[cstring] =
  ## Convert `Option[string]` to `Option[cstring]`
  if isSome val:
    result = some cstring get val
  else:
    result = none cstring

proc toInt*(val: Option[string]): Option[int] =
  ## Convert `Option[string]` to `Option[int]`
  if isSome val:
    result = some parseInt get val
  else:
    result = none int

proc to*(
  track: Track,
  listenedAt: Option[int]): APIListen =
  ## Convert a `Track` object to a `Listen` object
  let
    additionalInfo = AdditionalInfo(tracknumber: some $track.trackNumber,
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
                    releaseName = to listen.trackMetadata.releaseName,
                    recordingMbid = to get(listen.trackMetadata.additionalInfo).recordingMbid,
                    releaseMbid = to get(listen.trackMetadata.additionalInfo).releaseMbid,
                    artistMbids = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).artistMbids,
                    trackNumber = toInt get(listen.trackMetadata.additionalInfo, AdditionalInfo()).trackNumber,
                    listenedAt = listen.listenedAt,
                    preMirror = preMirror,
                    mirrored = some false)

proc to*(
  listens: seq[APIListen],
  preMirror: Option[bool] = none(bool)): seq[Track] =
  ## Convert a sequence of `Listen` objects to a sequence of `Track` objects
  for listen in listens:
    result.add to(listen, preMirror)

proc to*(
  userListens: UserListens,
  listenType: ListenType): SubmitListens =
  ## Convert a `UserListens` object to a `SubmitListens` object
  result = SubmitListens(listenType: listenType, payload: userListens.payload.listens)

proc getNowPlaying*(
  lb: AsyncListenBrainz,
  user: User): Future[Option[Track]] {.async.} =
  ## Return a ListenBrainz user's now playing
  let
    nowPlaying = await lb.getUserPlayingNow($user.services[listenBrainzService].username)
    payload = nowPlaying.payload
  if payload.count == 1:
    result = some(to(payload.listens[0]))
  else:
    result = none(Track)

proc getRecentTracks*(
  lb: AsyncListenBrainz,
  user: User,
  preMirror: bool): Future[seq[Track]] {.async.} =
  ## Return a ListenBrainz user's listen history
  let
    userListens = await lb.getUserListens($user.services[listenBrainzService].username)
  if userListens.payload.count > 0:
    result = to(userListens.payload.listens, some(preMirror))


# proc updateUser(username: cstring) {.async.} =
  ## Gets user's now playing, recents and updates db

proc initUser*(
  lb: AsyncListenBrainz,
  username: cstring): Future[User] {.async.} =
  ## Gets a given user's now playing, recent tracks and returns a `User` object
  var user = newUser(userId = username, services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username = username), Service.lastFmService: newServiceUser(Service.lastFmService)])
  user.playingNow = await lb.getNowPlaying(user)
  user.listenHistory = await lb.getRecentTracks(user, preMirror = true)
  return user

# index history by listenedAt
# on init: get now playing and history set tracks as premirror
# on update: get listens, add to history if greater than latestListenTS, set as mirrored only when submitted succesfully

# def submitMirrorQueue*
