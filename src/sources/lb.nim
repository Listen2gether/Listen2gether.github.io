when defined(js):
  import std/asyncjs
else:
  import std/asyncdispatch

import
  std/[times, strutils, unicode],
  pkg/[listenbrainz, union],
  pkg/listenbrainz/utils/api,
  pkg/listenbrainz/core,
  types, utils

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

proc to(tracks: seq[Listen], toMirror = false): seq[APIListen] =
  ## Convert a sequence of `Listen` objects to a sequence of `APIListen` objects.
  ## When `toMirror` is set, only tracks that have not been mirrored or are not pre-mirror are returned.
  for track in tracks:
    if toMirror:
      if not get(track.mirrored) and not get(track.preMirror):
        result.add to track
    else:
      result.add to track

proc to(listen: APIListen, preMirror, mirrored: Option[bool] = none(bool)): Listen =
  ## Convert an `APIListen` object to a `Listen` object.
  result = newListen(trackName = cstring listen.trackMetadata.trackName,
                    artistName = cstring listen.trackMetadata.artistName,
                    releaseName = to listen.trackMetadata.releaseName,
                    recordingMbid = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).recordingMbid,
                    releaseMbid = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).releaseMbid,
                    artistMbids = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).artistMbids,
                    trackNumber = unionToInt get(listen.trackMetadata.additionalInfo, AdditionalInfo()).tracknumber,
                    listenedAt = listen.listenedAt,
                    preMirror = preMirror,
                    mirrored = mirrored)

proc to(listens: seq[APIListen], preMirror, mirrored: Option[bool] = none(bool)): seq[Listen] =
  ## Convert a sequence of `APIListen` objects to a sequence of `Listen` objects
  for listen in listens:
    result.add to(listen, preMirror, mirrored)

proc getNowPlaying(lb: AsyncListenBrainz, username: cstring, preMirror: bool): Future[Option[Listen]] {.async.} =
  ## Return a ListenBrainz user's now playing
  try:
    let
      nowPlaying = await lb.getUserPlayingNow($username)
      payload = nowPlaying.payload
    if payload.count == 1:
      return some to(payload.listens[0], preMirror = some preMirror, mirrored = some false)
    else:
      return none Listen
  except JsonError:
    logError("There was a problem parsing $#'s now playing!" % $username)
  except HttpRequestError:
    logError("There was a problem getting $#'s now playing!" % $username)

proc getRecentTracks(lb: AsyncListenBrainz, username: cstring, preMirror: bool, maxTs, minTs: int = 0, count: int = 100): Future[seq[Listen]] {.async.} =
  ## Return a ListenBrainz user's listen history
  try:
    let userListens = await lb.getUserListens($username, minTs, maxTs, count)
    echo repr userListens
    return to(userListens.payload.listens, some preMirror, some false)
  except JsonError:
    logError("There was a problem parsing $#'s listens!" % $username)
  except HttpRequestError:
    logError("There was a problem getting $#'s listens!" % $username)

proc initUser*(lb: AsyncListenBrainz, username: cstring, token: cstring = "", selected = false): Future[User] {.async.} =
  ## Gets a given ListenBrainz user's now playing, recent tracks, and latest listen timestamp.
  ## Returns a `User` object
  let username = cstring toLower($username)
  var user = newUser(username, Service.listenBrainzService, token, selected = selected)
  user.lastUpdateTs = int toUnix getTime()
  user.playingNow = await lb.getNowPlaying(username, preMirror = true)
  user.listenHistory = await lb.getRecentTracks(username, preMirror = true)
  return user

proc updateUser*(lb: AsyncListenBrainz, user: User, resetLastUpdate, preMirror = false): Future[User] {.async.} =
  ## Updates ListenBrainz user's now playing, recent tracks, and latest listen timestamp
  var updatedUser = user
  if resetLastUpdate or user.listenHistory.len > 0:
    updatedUser.lastUpdateTs = get user.listenHistory[0].listenedAt
  else:
    updatedUser.lastUpdateTs = int toUnix getTime()

  if resetLastUpdate:
    let
      latestListenHistory = await lb.getRecentTracks(user.username, preMirror)
      maxTs = get latestListenHistory[^1].listenedAt

    if maxTs > updatedUser.lastUpdateTs: # fills in any gaps in history
      var listenHistory = await lb.getRecentTracks(user.username, preMirror, minTs = updatedUser.lastUpdateTs, maxTs = maxTs)
      updatedUser.listenHistory = listenHistory & user.listenHistory
      while listenHistory.len > 0:
        listenHistory = await lb.getRecentTracks(user.username, preMirror, minTs = updatedUser.lastUpdateTs, maxTs = maxTs)
        updatedUser.listenHistory = listenHistory & updatedUser.listenHistory
      updatedUser.playingNow = await lb.getNowPlaying(user.username, preMirror)
      updatedUser.listenHistory = latestListenHistory & updatedUser.listenHistory
    else: # no gap / overlap
      updatedUser.playingNow = await lb.getNowPlaying(user.username, preMirror)
      let listenHistory = await lb.getRecentTracks(user.username, preMirror, minTs = updatedUser.lastUpdateTs)
      updatedUser.listenHistory = listenHistory & user.listenHistory
  else:
    updatedUser.playingNow = await lb.getNowPlaying(user.username, preMirror)
    let listenHistory = await lb.getRecentTracks(user.username, preMirror, minTs = user.lastUpdateTs)
    updatedUser.listenHistory = listenHistory & user.listenHistory
  return updatedUser

proc pageUser*(lb: AsyncListenBrainz, user: var User, endInd: var int, `inc`: int = 10) {.async.} =
  ## Backfills ListenBrainz user's recent tracks
  let
    maxTs = get user.listenHistory[^1].listenedAt
    newTracks = await lb.getRecentTracks(user.username, preMirror = true, maxTs = maxTs)
  user.listenHistory = user.listenHistory & newTracks
  endInd += `inc`

proc submitMirrorQueue*(lb: AsyncListenBrainz, user: var User) {.async.} =
  ## Submits ListenBrainz user's now playing and listen history that are not `mirrored` or `preMirror`
  if isSome user.playingNow:
    if not get(get(user.playingNow).preMirror) and not get(get(user.playingNow).mirrored):
      let
        listen = to get user.playingNow
        playingNow = newSubmitListens(listenType = ListenType.playingNow, @[listen])
      try:
        discard lb.submitListens(playingNow)
        get(user.playingNow).mirrored = some true
      except HttpRequestError:
        logError("There was a problem submitting your now playing!")

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
      logError("There was a problem submitting your listens!")
