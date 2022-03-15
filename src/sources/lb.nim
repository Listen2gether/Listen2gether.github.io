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
    var list: seq[string]
    for item in val.get():
      list.add $item
    result = some list
  else:
    result = none seq[string]

proc to*(val: Option[seq[string]]): Option[seq[cstring]] =
  ## Convert `Option[seq[string]]` to `Option[seq[cstring]]`
  if isSome val:
    var list: seq[cstring]
    for item in val.get():
      list.add cstring item
    result = some list
  else:
    result = none seq[cstring]

proc to*(val: Option[string]): Option[cstring] =
  ## Convert `Option[string]` to `Option[cstring]`
  if isSome val:
    result = some cstring get val
  else:
    result = none cstring

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
                    releaseName = to listen.trackMetadata.releaseName,
                    recordingMbid = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).recordingMbid,
                    releaseMbid = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).releaseMbid,
                    artistMbids = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).artistMbids,
                    trackNumber = get(listen.trackMetadata.additionalInfo, AdditionalInfo()).trackNumber,
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
  username: cstring): Future[Option[Track]] {.async.} =
  ## Return a ListenBrainz user's now playing
  let
    nowPlaying = await lb.getUserPlayingNow($username)
    payload = nowPlaying.payload
  if payload.count == 1:
    result = some(to(payload.listens[0]))
  else:
    result = none(Track)

proc getRecentTracks*(
  lb: AsyncListenBrainz,
  username: cstring,
  latestListenTs: int,
  preMirror: bool): Future[seq[Track]] {.async.} =
  ## Return a ListenBrainz user's listen history
  let userListens = await lb.getUserListens($username, minTs = latestListenTs)
  result = to(userListens.payload.listens, some(preMirror))

proc updateLatestListenTs*(user: var User) =
  ## Updates a user's `latestListenTs` from their `listenHistory`
  if user.listenHistory.len > 0:
    if isSome user.listenHistory[0].listenedAt:
      user.latestListenTs = get user.listenHistory[0].listenedAt

proc initUser*(
  lb: AsyncListenBrainz,
  username: cstring,
  token: cstring = ""): Future[User] {.async.} =
  ## Gets a given user's now playing, recent tracks, and latest listen timestamp.
  ## Returns a `User` object
  var user = newUser(userId = username, services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username = username, token = token), Service.lastFmService: newServiceUser(Service.lastFmService)])
  user.playingNow = await lb.getNowPlaying(username)
  user.listenHistory = await lb.getRecentTracks(username, user.latestListenTs, preMirror = true)
  updateLatestListenTs(user)
  return user

proc updateUser*(
  lb: AsyncListenBrainz,
  user: User,
  preMirror = true): Future[User] {.async.} =
  ## Updates user's now playing, recent tracks, and latest listen timestamp
  var updatedUser = user
  updatedUser.playingNow = await lb.getNowPlaying(user.services[listenBrainzService].username)
  updatedUser.listenHistory = await lb.getRecentTracks(user.services[listenBrainzService].username, user.latestListenTs, preMirror)
  updateLatestListenTs(updatedUser)
  return updatedUser

# index history by listenedAt
# on init: get now playing and history set tracks as premirror
# on update: get listens, add to history if greater than latestListenTS, set as mirrored only when submitted succesfully

# def submitMirrorQueue*
