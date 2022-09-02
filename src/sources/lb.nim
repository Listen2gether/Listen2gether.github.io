## ListenBrainz module
## This contains support for the ListenBrainz backend.
##

when defined(js):
  import std/asyncjs
else:
  import std/asyncdispatch

import
  std/[times, strutils, unicode, sugar],
  pkg/[listenbrainz, union],
  pkg/listenbrainz/utils/api,
  pkg/listenbrainz/core,
  types, utils, pure

include pkg/listenbrainz/utils/tools

const userBaseUrl*: cstring = "https://listenbrainz.org/user/"

proc to(track: Listen): APIListen =
  ## Convert a `Listen` object to an `APIListen` object
  let
    additionalInfo = newAdditionalInfo(tracknumber = to(track.trackNumber) as union(Option[string] | Option[int]),
                                      trackMbid = to track.recordingMbid,
                                      recordingMbid = to track.recordingMbid,
                                      releaseMbid = to track.releaseMbid,
                                      artistMbids = to track.artistMbids)
    trackMetadata = newTrackMetadata(trackName = $track.trackName,
                                    artistName = $track.artistName,
                                    releaseName = to track.releaseName,
                                    additionalInfo = some additionalInfo)
  result = newAPIListen(listenedAt = track.listenedAt, trackMetadata = trackMetadata)

proc to(tracks: seq[Listen]): seq[APIListen] =
  ## Convert a sequence of `Listen` objects to a sequence of `APIListen` objects.
  result = collect:
    for track in tracks:
      to track

proc to(listen: APIListen): Listen =
  ## Convert an `APIListen` object to a `Listen` object.
  result = newListen(trackName = cstring listen.trackMetadata.trackName,
                    artistName = cstring listen.trackMetadata.artistName,
                    releaseName = to listen.trackMetadata.releaseName,
                    recordingMbid = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).recordingMbid,
                    releaseMbid = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).releaseMbid,
                    artistMbids = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).artistMbids,
                    trackNumber = unionToInt get(listen.trackMetadata.additionalInfo, AdditionalInfo()).tracknumber,
                    listenedAt = listen.listenedAt)

proc to(listens: seq[APIListen]): seq[Listen] =
  ## Convert a sequence of `APIListen` objects to a sequence of `Listen` objects
  result = collect:
    for listen in listens:
      to listen

proc getNowPlaying(lb: AsyncListenBrainz, username: cstring): Future[Option[Listen]] {.async.} =
  ## Return a ListenBrainz user's now playing
  try:
    let
      nowPlaying = await lb.getUserPlayingNow($username)
      payload = nowPlaying.payload
    if payload.count == 1:
      return some to(payload.listens[0])
    else:
      return none Listen
  except JsonError:
    logError("There was a problem parsing $#'s now playing!" % $username)
  except HttpRequestError:
    logError("There was a problem getting $#'s now playing!" % $username)

proc getRecentTracks(lb: AsyncListenBrainz, username: cstring, maxTs, minTs: int = 0, count: int = 100): Future[seq[Listen]] {.async.} =
  ## Return a ListenBrainz user's listen history
  try:
    let userListens = await lb.getUserListens($username, minTs, maxTs, count)
    return to(userListens.payload.listens)
  except JsonError:
    logError("There was a problem parsing $#'s listens!" % $username)
  except HttpRequestError:
    logError("There was a problem getting $#'s listens!" % $username)

proc initUser*(lb: AsyncListenBrainz, username: cstring, token: cstring = ""): Future[User] {.async.} =
  ## Gets a given ListenBrainz user's now playing, recent tracks, and latest listen timestamp.
  ## Returns a `User` object
  let username = cstring toLower($username)
  var user = newUser(username, Service.listenBrainzService, token)
  user.playingNow = await lb.getNowPlaying(username)
  user.listenHistory = await lb.getRecentTracks(username)
  return user

proc updateUser*(lb: AsyncListenBrainz, user: User, resetLastUpdate = false): Future[User] {.async.} =
  ## Updates ListenBrainz user's history.

  var updatedUser = user
  if resetLastUpdate or user.listenHistory.len > 0:
    updatedUser.lastUpdateTs = get user.listenHistory[0].listenedAt
  else:
    updatedUser.lastUpdateTs = int toUnix getTime()

  if resetLastUpdate:
    let
      latestListenHistory = await lb.getRecentTracks(user.username)
      maxTs = get latestListenHistory[^1].listenedAt

    if maxTs > updatedUser.lastUpdateTs: # fills in any gaps in history
      var listenHistory = await lb.getRecentTracks(user.username, minTs = updatedUser.lastUpdateTs, maxTs = maxTs)
      updatedUser.listenHistory = listenHistory & user.listenHistory
      while listenHistory.len > 0:
        listenHistory = await lb.getRecentTracks(user.username, minTs = updatedUser.lastUpdateTs, maxTs = maxTs)
        updatedUser.listenHistory = listenHistory & updatedUser.listenHistory
      updatedUser.playingNow = await lb.getNowPlaying(user.username)
      updatedUser.listenHistory = latestListenHistory & updatedUser.listenHistory
    else: # no gap / overlap
      updatedUser.playingNow = await lb.getNowPlaying(user.username)
      let listenHistory = await lb.getRecentTracks(user.username, minTs = updatedUser.lastUpdateTs)
      updatedUser.listenHistory = listenHistory & user.listenHistory
  else:
    updatedUser.playingNow = await lb.getNowPlaying(user.username)
    let listenHistory = await lb.getRecentTracks(user.username, minTs = user.lastUpdateTs)
    updatedUser.listenHistory = listenHistory & user.listenHistory
  return updatedUser

proc pageUser*(lb: AsyncListenBrainz, user: var User, endInd: var int, `inc` = 10) {.async.} =
  ## Backfills ListenBrainz user's recent tracks
  let
    maxTs = get user.listenHistory[^1].listenedAt
    newTracks = await lb.getRecentTracks(user.username, maxTs = maxTs)
  user.listenHistory = user.listenHistory & newTracks
  endInd += `inc`

proc submitMirrorQueue*(lb: AsyncListenBrainz, user: var User) {.async.} =
  ## Submits ListenBrainz user's mirror queue including playing now, and updates the `lastSubmissionTs`.
  if user.submitQueue.playingNow.isSome():
    let
      listen = to get user.playingNow
      playingNow = newSubmitListens(listenType = ListenType.playingNow, @[listen])
    try:
      discard lb.submitListens(playingNow)
      user.submitQueue.playingNow = none Listen
    except HttpRequestError:
      logError("There was a problem submitting your now playing!")
  if user.submitQueue.listens.len > 0:
    try:
      let payload = newSubmitListens(listenType = ListenType.import, to(user.submitQueue.listens))
      discard lb.submitListens(payload)
      user.lastSubmissionTs = user.submitQueue.listens[0].listenedAt
      user.submitQueue.listens = @[]
    except HttpRequestError:
      logError("There was a problem submitting your listens!")
