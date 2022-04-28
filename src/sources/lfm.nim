when defined(js):
  import std/asyncjs
else:
  import std/asyncdispatch

import
  std/[json, options, strutils, times],
  pkg/[jsony, lastfm],
  pkg/lastfm/[track, user],
  types, utils

const
  userBaseUrl* = "https://last.fm/user/"
  apiKey* = "f6cbd0de2ace1b377de4ed27f73af158"
  apiSecret* = "6a037eaccb1957d1b63354b02a4eeb62"

type
  FMTrack* = object
    artist*, album*: JsonNode
    date*: Option[FMDate]
    mbid*, name*, url*: Option[string]
    `@attr`*: Option[Attributes]

  FMDate* = object
    uts*, text*: string

  Attributes* = object
    nowplaying*: string

  Scrobble* = object
    track*, artist*: string
    album*, mbid*, albumArtist*: Option[string]
    timestamp*, trackNumber*, duration*: Option[int]

func newFMTrack(
  artist, album: JsonNode,
  date: Option[FMDate] = none(FMDate),
  mbid, name, url: Option[string] = none(string),
  `@attr`: Option[Attributes] = none(Attributes)): FMTrack =
  ## Create new `FMTrack` object
  result.artist = artist
  result.album = album
  result.date = date
  result.mbid = mbid
  result.name = name
  result.url = url
  result.`@attr` = `@attr`

func newAttributes(nowplaying: string): Attributes =
  ## Create new `Attributes` object
  result.nowplaying = nowplaying

func newScrobble(
  track, artist: string,
  album, mbid, albumArtist: Option[string] = none(string),
  timestamp, trackNumber, duration: Option[int] = none(int)): Scrobble =
  ## Create new `Scrobble` object
  result.track = track
  result.artist = artist
  result.timestamp = timestamp
  result.album = album
  result.mbid = mbid
  result.albumArtist = albumArtist
  result.trackNumber = trackNumber
  result.duration = duration

func getVal(node: JsonNode, index: string): Option[cstring] = to getStr node{index}

func parseDate(date: Option[FMDate]): Option[int] =
  ## convert `Option[FMDate]` date to `Option[int]
  if isSome date:
    result = some parseInt get(date).uts
  else:
    result = none int

func parseMbids(mbid: string): Option[seq[cstring]] =
  if isEmptyOrWhitespace mbid:
    result = none seq[cstring]
  else:
    result = some @[cstring mbid]

func to(
  fmTrack: FMTrack,
  preMirror, mirrored: Option[bool] = none(bool)): Listen =
  ## Convert an `FMTrack` object to a `Listen` object
  result = newListen(trackName = cstring get fmTrack.name,
                    artistName = get getVal(fmTrack.artist, "#text"),
                    releaseName = getVal(fmTrack.album, "#text"),
                    recordingMbid = to fmTrack.mbid,
                    releaseMbid = getVal(fmTrack.album, "mbid"),
                    artistMbids = parseMbids getStr fmTrack.artist{"mbid"},
                    listenedAt = parseDate fmTrack.date,
                    preMirror = preMirror,
                    mirrored = mirrored)

func to(
  fmTracks: seq[FMTrack],
  preMirror, mirrored: Option[bool] = none(bool)): seq[Listen] =
  ## Convert a sequence of `FMTrack` objects to a sequence of `Listen` objects
  for fmTrack in fmTracks:
    result.add to(fmTrack, preMirror, mirrored)

func to(scrobble: Scrobble,
  preMirror, mirrored: Option[bool] = none(bool)): Listen =
  ## Convert a `Scrobble` object to a `Listen` object
  result = newListen(trackName = cstring scrobble.track,
                    artistName = cstring scrobble.artist,
                    releaseName = to scrobble.album,
                    artistMbids = to some @[get scrobble.mbid],
                    trackNumber = scrobble.trackNumber,
                    listenedAt = scrobble.timestamp,
                    preMirror = preMirror,
                    mirrored = mirrored)

func to(
  listens: seq[Scrobble],
  preMirror, mirrored: Option[bool] = none(bool)): seq[Listen] =
  ## Convert a sequence of `Scrobble` objects to a sequence of `Listen` objects
  for listen in listens:
    result.add to(listen, preMirror, mirrored)

func to(listen: Listen): Scrobble =
  ## Convert a `Listen` object to a `Scrobble` object
  result = newScrobble(track = $listen.trackName,
                      artist = $listen.artistName,
                      timestamp = listen.listenedAt,
                      album = to listen.releaseName,
                      mbid = to listen.recordingMbid,
                      albumArtist = some $listen.artistName,
                      trackNumber = listen.trackNumber)

func to(tracks: seq[Listen], toMirror = false): seq[Scrobble] =
  ## Convert a sequence of `Listen` objects to a sequence of `Scrobble` objects.
  ## When `toMirror` is set, only tracks that have not been mirrored or are not pre-mirror are returned.
  for track in tracks:
    if toMirror and not get(track.mirrored) and not get(track.preMirror):
        result.add to track
    else:
      result.add to track

proc setNowPlayingTrack(
  fm: AsyncLastFM,
  scrobble: Scrobble): Future[JsonNode] {.async.} =
  ## Sets the current playing track on Last.FM
  try:
    result = await fm.setNowPlaying(track = scrobble.track,
                              artist = scrobble.artist,
                              album = get scrobble.album,
                              mbid = get scrobble.mbid,
                              albumArtist = get scrobble.albumArtist,
                              trackNumber = scrobble.trackNumber,
                              duration = scrobble.duration)
  except:
    logError "There was a problem setting your now playing!"

proc scrobbleTrack(
  fm: AsyncLastFM,
  scrobble: Scrobble): Future[JsonNode] {.async.} =
  ## Scrobble a track to Last.FM
  try:
    result = await fm.scrobble(track = scrobble.track,
      artist = scrobble.artist,
      timestamp = get scrobble.timestamp,
      album = get scrobble.album,
      mbid = get scrobble.mbid,
      albumArtist = get scrobble.albumArtist,
      trackNumber = scrobble.trackNumber,
      duration = scrobble.duration)
  except:
    logError "There was a problem scrobbling " & scrobble.track & " - " & scrobble.artist & "!"

proc scrobbleTracks(
  fm: AsyncLastFM,
  scrobbles: seq[Scrobble]): Future[seq[JsonNode]] {.async.} =
  var futures: seq[JsonNode]
  for scrobble in scrobbles:
    futures.add await fm.scrobbleTrack(scrobble)

proc getRecentTracks(
  fm: AsyncLastFM,
  username: cstring,
  preMirror: bool,
  `from`, upTo = 0,
  limit = 100): Future[(Option[Listen], seq[Listen])] {.async.} =
  ## Return a Last.FM user's listen history and now playing
  var
    playingNow: Option[Listen]
    listenHistory: seq[Listen]
  try:
    let
      recentTracks = await fm.userRecentTracks(user = $username, limit = limit, `from` = `from`, to = upTo)
      tracks = recentTracks["recenttracks"]["track"]
    if tracks.len == limit:
      listenHistory = to(fromJson($tracks, seq[FMTrack]), preMirror = some preMirror, mirrored = some false)
    elif tracks.len == limit+1:
      playingNow = some to(fromJson($tracks[0], FMTrack), preMirror = some preMirror)
      # potential speedup: tracks[1..^1].mapIt(it.to(FMTrack))
      listenHistory = to(fromJson($tracks[1..^1], seq[FMTrack]), preMirror = some preMirror, mirrored = some false)
    return (playingNow, listenHistory)
  except HttpRequestError:
    logError "There was a problem getting " & $username & "'s listens!"

proc initUser*(
  fm: AsyncLastFM,
  username: cstring,
  sessionKey: cstring = ""): Future[User] {.async.} =
  ## Gets a given user's now playing, recent tracks, and latest listen timestamp.
  ## Returns a `User` object
  let userId = cstring($Service.lastFmService & ":" & $username)
  var user = newUser(userId = userId, services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService), Service.lastFmService: newServiceUser(Service.lastFmService, username, sessionKey = sessionKey)])
  user.lastUpdateTs = int toUnix getTime()
  let (playingNow, listenHistory) = await fm.getRecentTracks(username, preMirror = true)
  user.playingNow = playingNow
  user.listenHistory = listenHistory
  return user

proc updateUser*(
  fm: AsyncLastFM,
  user: User,
  resetLastUpdate, preMirror = false): Future[User] {.async.} =
  ## Updates user's now playing, recent tracks, and latest listen timestamp
  var updatedUser = user
  if resetLastUpdate or user.listenHistory.len > 0:
    updatedUser.lastUpdateTs = get user.listenHistory[0].listenedAt
  else:
    updatedUser.lastUpdateTs = int toUnix getTime()
  let (playingNow, listenHistory) = await fm.getRecentTracks(user.services[lastFmService].username, `from` = user.lastUpdateTs, preMirror = false)
  updatedUser.playingNow = playingNow
  updatedUser.listenHistory = listenHistory & user.listenHistory
  return updatedUser

proc pageUser*(
  fm: AsyncLastFM,
  user: var User,
  endInd: var int,
  inc: int = 10) {.async.} =
  ## Backfills user's recent tracks
  let
    to = get user.listenHistory[^1].listenedAt
    (playingNow, listenHistory) = await fm.getRecentTracks(user.services[lastFmService].username, preMirror = true, upTo = to)
  user.playingNow = playingNow
  user.listenHistory = user.listenHistory & listenHistory
  endInd += inc

proc submitMirrorQueue*(
  fm: AsyncLastFM,
  user: var User) {.async.} =
  ## Submits user's now playing and listen history that are not mirrored or preMirror
  if isSome user.playingNow:
    if not get(get(user.playingNow).preMirror) and not get(get(user.playingNow).mirrored):
      try:
        discard fm.setNowPlayingTrack(to get user.playingNow)
      except:
        logError "There was a problem submitting your now playing!"

  let scrobbles = to(user.listenHistory, toMirror = true)
  if scrobbles.len > 0:
    try:
      discard fm.scrobbleTracks scrobbles
      let mirroredTracks = to scrobbles
      for idx, track in user.listenHistory[0..^1]:
        if track in mirroredTracks:
          user.listenHistory[idx].mirrored = some true
    except:
      logError "There was a problem submitting your scrobbles!"
