when defined(js):
  import std/asyncjs
else:
  import std/asyncdispatch

import
  std/[times, strutils, unicode],
  pkg/listenbrainz,
  pkg/listenbrainz/utils/api,
  pkg/listenbrainz/core,
  types, utils

include pkg/listenbrainz/utils/tools

const userBaseUrl*: cstring = "https://listenbrainz.org/user/"

func to(track: Listen): APIListen =
  ## Convert a `Listen` object to an `APIListen` object
  let
    additionalInfo = newAdditionalInfo(# tracknumber = to track.trackNumber,
                                    trackMbid = to track.recordingMbid,
                                    recordingMbid = to track.recordingMbid,
                                    releaseMbid = to track.releaseMbid,
                                    artistMbids = to track.artistMbids)
    trackMetadata = newTrackMetadata(trackName = $track.trackName,
                                  artistName = $track.artistName,
                                  releaseName = to track.releaseName,
                                  additionalInfo = some additionalInfo)
  result = newAPIListen(listenedAt = track.listenedAt, trackMetadata = trackMetadata)

func to(tracks: seq[Listen], toMirror = false): seq[APIListen] =
  ## Convert a sequence of `Listen` objects to a sequence of `APIListen` objects.
  ## When `toMirror` is set, only tracks that have not been mirrored or are not pre-mirror are returned.
  for track in tracks:
    if toMirror:
      if not get(track.mirrored) and not get(track.preMirror):
        result.add to track
    else:
      result.add to track

func to(listen: APIListen, preMirror, mirrored: Option[bool] = none(bool)): Listen =
  ## Convert an `APIListen` object to a `Listen` object.
  result = newListen(trackName = cstring listen.trackMetadata.trackName,
                    artistName = cstring listen.trackMetadata.artistName,
                    releaseName = to listen.trackMetadata.releaseName,
                    recordingMbid = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).recordingMbid,
                    releaseMbid = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).releaseMbid,
                    artistMbids = to get(listen.trackMetadata.additionalInfo, AdditionalInfo()).artistMbids,
                    # trackNumber = toInt get(listen.trackMetadata.additionalInfo, AdditionalInfo()).tracknumber,
                    listenedAt = listen.listenedAt,
                    preMirror = preMirror,
                    mirrored = mirrored)

func to(listens: seq[APIListen], preMirror, mirrored: Option[bool] = none(bool)): seq[Listen] =
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
      result = some to(payload.listens[0], preMirror = some preMirror, mirrored = some false)
    else:
      result = none Listen
  except JsonError:
    logError "There was a problem parsing" & $username & "'s now playing!"
  except HttpRequestError:
    logError "There was a problem getting " & $username & "'s now playing!"

proc getRecentTracks(lb: AsyncListenBrainz, username: cstring, preMirror: bool, maxTs, minTs: int = 0, count: int = 100): Future[seq[Listen]] {.async.} =
  ## Return a ListenBrainz user's listen history
  try:
    let userListens = await lb.getUserListens($username, maxTs = maxTs, minTs = minTs, count = count)
    result = to(userListens.payload.listens, some preMirror, mirrored = some false)
  except JsonError:
    logError "There was a problem parsing " & $username & "'s listens!"
  except HttpRequestError:
    logError "There was a problem getting " & $username & "'s listens!"

proc initUser*(lb: AsyncListenBrainz, username: cstring, token: cstring = ""): Future[User] {.async.} =
  ## Gets a given ListenBrainz user's now playing, recent tracks, and latest listen timestamp.
  ## Returns a `User` object
  let
    username = cstring toLower($username)
    userId = cstring($Service.listenBrainzService & ":" & $username)
  var user = newUser(userId = userId, services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username = username, token = token), Service.lastFmService: newServiceUser(Service.lastFmService)])
  user.lastUpdateTs = int toUnix getTime()
  user.playingNow = await lb.getNowPlaying(username, preMirror = true)
  user.listenHistory = await lb.getRecentTracks(username, preMirror = true)
  return user

proc updateUser*(lb: AsyncListenBrainz, user: User, resetLastUpdate, preMirror = false): Future[User] {.async.} =
  ## Updates ListenBrainz user's now playing, recent tracks, and latest listen timestamp
  let username = user.services[listenBrainzService].username
  var updatedUser = user
  if resetLastUpdate or user.listenHistory.len > 0:
    updatedUser.lastUpdateTs = get user.listenHistory[0].listenedAt
  else:
    updatedUser.lastUpdateTs = int toUnix getTime()

  if resetLastUpdate:
    let
      latestListenHistory = await lb.getRecentTracks(username, preMirror)
      maxTs = get latestListenHistory[^1].listenedAt

    if maxTs > updatedUser.lastUpdateTs: # fills in any gaps in history
      var listenHistory = await lb.getRecentTracks(username, preMirror, minTs = updatedUser.lastUpdateTs, maxTs = maxTs)
      updatedUser.listenHistory = listenHistory & user.listenHistory
      while listenHistory.len > 0:
        listenHistory = await lb.getRecentTracks(username, preMirror, minTs = updatedUser.lastUpdateTs, maxTs = maxTs)
        updatedUser.listenHistory = listenHistory & updatedUser.listenHistory
      updatedUser.playingNow = await lb.getNowPlaying(username, preMirror)
      updatedUser.listenHistory = latestListenHistory & updatedUser.listenHistory
    else: # no gap / overlap
      updatedUser.playingNow = await lb.getNowPlaying(username, preMirror)
      let listenHistory = await lb.getRecentTracks(username, preMirror, minTs = updatedUser.lastUpdateTs)
      updatedUser.listenHistory = listenHistory & user.listenHistory
  else:
    updatedUser.playingNow = await lb.getNowPlaying(username, preMirror)
    let listenHistory = await lb.getRecentTracks(username, preMirror, minTs = user.lastUpdateTs)
    updatedUser.listenHistory = listenHistory & user.listenHistory
  return updatedUser

proc pageUser*(lb: AsyncListenBrainz, user: var User, endInd: var int, `inc`: int = 10) {.async.} =
  ## Backfills ListenBrainz user's recent tracks
  let
    maxTs = get user.listenHistory[^1].listenedAt
    newTracks = await lb.getRecentTracks(user.services[listenBrainzService].username, preMirror = true, maxTs = maxTs)
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
        logError "There was a problem submitting your now playing!"

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
      logError "There was a problem submitting your listens!"
