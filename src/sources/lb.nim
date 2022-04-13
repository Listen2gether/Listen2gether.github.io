when defined(js):
  import std/asyncjs
else:
  import
    std/asyncdispatch

import
  std/[times, strutils],
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

proc to*(val: Option[cstring]): Option[string] =
  ## Convert `Option[cstring]` to `Option[string]`
  if isSome val:
    result = some $get(val)
  else:
    result = none string

proc to*(track: Listen): APIListen =
  ## Convert a `Listen` object to an `APIListen` object
  let
    additionalInfo = AdditionalInfo(tracknumber: track.trackNumber,
                                    trackMbid: to track.recordingMbid,
                                    recordingMbid: to track.recordingMbid,
                                    releaseMbid: to track.releaseMbid,
                                    artistMbids: to track.artistMbids)
    trackMetadata = TrackMetadata(trackName: $track.trackName,
                                  artistName: $track.artistName,
                                  releaseName: to track.releaseName,
                                  additionalInfo: some additionalInfo)
  result = APIListen(listenedAt: track.listenedAt,
                     trackMetadata: trackMetadata)

proc to*(tracks: seq[Listen], toMirror = false): seq[APIListen] =
  ## Convert a sequence of `Listen` objects to a sequence of `APIListen` objects.
  ## When `toMirror` is set, only tracks that have not been mirrored or are not pre-mirror are returned.
  for track in tracks:
    if toMirror:
      if not get(track.mirrored) and not get(track.preMirror):
        result.add to track
    else:
      result.add to track

proc to*(
  listen: APIListen,
  preMirror, mirrored: Option[bool] = none(bool)): Listen =
  ## Convert an `APIListen` object to a `Listen` object.
  result = newListen(trackName = cstring listen.trackMetadata.trackName,
                    artistName = cstring listen.trackMetadata.artistName,
                    releaseName = to listen.trackMetadata.releaseName,
                    recordingMbid = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).recordingMbid,
                    releaseMbid = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).releaseMbid,
                    artistMbids = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).artistMbids,
                    trackNumber = get(listen.trackMetadata.additionalInfo, AdditionalInfo()).tracknumber,
                    listenedAt = listen.listenedAt,
                    preMirror = preMirror,
                    mirrored = mirrored)

proc to*(
  listens: seq[APIListen],
  preMirror, mirrored: Option[bool] = none(bool)): seq[Listen] =
  ## Convert a sequence of `APIListen` objects to a sequence of `Listen` objects
  for listen in listens:
    result.add to(listen, preMirror, mirrored)

proc to*(
  userListens: UserListens,
  listenType: ListenType): SubmitListens =
  ## Convert a `UserListens` object to a `SubmitListens` object
  result = SubmitListens(listenType: listenType, payload: userListens.payload.listens)

func `==`*(a, b: Listen): bool =
  ## does not include `mirrored` or `preMirror`
  return a.trackName == b.trackName and
    a.artistName == b.artistName and
    a.releaseName == b.releaseName and
    a.artistMbids == b.artistMbids and
    a.trackNumber == b.trackNumber

proc getNowPlaying*(
  lb: AsyncListenBrainz,
  username: cstring,
  preMirror: bool = true): Future[Option[Listen]] {.async.} =
  ## Return a ListenBrainz user's now playing
  try:
    let
      nowPlaying = await lb.getUserPlayingNow($username)
      payload = nowPlaying.payload
    if payload.count == 1:
      result = some to(payload.listens[0], preMirror = some preMirror)
    else:
      result = none Listen
  except HttpRequestError:
    echo "Error: There was a problem getting " & $username & "'s now playing!"

proc getRecentTracks*(
  lb: AsyncListenBrainz,
  username: cstring,
  preMirror: bool,
  maxTs, minTs: int = 0,
  count: int = 100): Future[seq[Listen]] {.async.} =
  ## Return a ListenBrainz user's listen history
  try:
    let userListens = await lb.getUserListens($username, maxTs = maxTs, minTs = minTs, count = count)
    result = to(userListens.payload.listens, some preMirror, mirrored = some false)
  except HttpRequestError:
    echo "ERROR: There was a problem getting " & $username & "'s listens!"

proc initUser*(
  lb: AsyncListenBrainz,
  username: cstring,
  token: cstring = ""): Future[User] {.async.} =
  ## Gets a given user's now playing, recent tracks, and latest listen timestamp.
  ## Returns a `User` object
  let userId = cstring($Service.listenBrainzService & ":" & $username)
  var user = newUser(userId = userId, services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username = username, token = token), Service.lastFmService: newServiceUser(Service.lastFmService)])
  user.lastUpdateTs = int toUnix getTime()
  user.playingNow = await lb.getNowPlaying(username)
  user.listenHistory = await lb.getRecentTracks(username, preMirror = true)
  return user

proc updateUser*(
  lb: AsyncListenBrainz,
  user: User,
  resetLastUpdate, preMirror = false): Future[User] {.async.} =
  ## Updates user's now playing, recent tracks, and latest listen timestamp
  var updatedUser = user
  if resetLastUpdate or user.listenHistory.len > 0:
    updatedUser.lastUpdateTs = get user.listenHistory[0].listenedAt
  else:
    updatedUser.lastUpdateTs = int toUnix getTime()
  updatedUser.playingNow = await lb.getNowPlaying(user.services[listenBrainzService].username, preMirror = false)
  let newTracks = await lb.getRecentTracks(user.services[listenBrainzService].username, preMirror, minTs = user.lastUpdateTs)
  updatedUser.listenHistory = newTracks & user.listenHistory
  return updatedUser

proc pageUser*(
  lb: AsyncListenBrainz,
  user: var User,
  endInd: var int,
  inc: int = 10) {.async.} =
  ## Backfills user's recent tracks
  let
    maxTs = get user.listenHistory[^1].listenedAt
    newTracks = await lb.getRecentTracks(user.services[listenBrainzService].username, preMirror = true, maxTs = maxTs)
  user.listenHistory = user.listenHistory & newTracks
  endInd += inc

proc submitMirrorQueue*(
  lb: AsyncListenBrainz,
  user: var User) {.async.} =
  ## Submits user's now playing and listen history that are not mirrored or preMirror
  if isSome user.playingNow:
    let
      listen = to get user.playingNow
      playingNow = newSubmitListens(listenType = ListenType.playingNow, @[listen])
    try:
      discard lb.submitListens(playingNow)
    except HttpRequestError:
      echo "ERROR: There was a problem submitting your now playing!"

  let listens = to(user.listenHistory, toMirror = true)
  if listens.len > 0:
    try:
      let payload = newSubmitListens(listenType = ListenType.import, listens)
      discard lb.submitListens(payload)
      let mirroredTracks = to listens
      for idx, track in user.listenHistory[0..^1]:
        if track in mirroredTracks:
          user.listenHistory[idx].mirrored = some true
    except HttpRequestError:
      echo "ERROR: There was a problem submitting your listens!"
