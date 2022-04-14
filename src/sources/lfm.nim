when defined(js):
  import std/asyncjs
else:
  import std/asyncdispatch

import
  std/[json, options, strutils, times],
  pkg/[jsony, lastfm],
  pkg/lastfm/[track, user],
  utils,
  ../types

const
  userBaseUrl* = "https://last.fm/user/"
  apiKey* = ""
  apiSecret* = ""

type
  FMTrack* = object
    artist*, album*: JsonNode
    date*: Option[JsonNode]
    mbid*, name*, url*: Option[string]
    `@attr`*: Option[Attributes]

  Attributes* = object
    nowplaying*: string

  Scrobble* = object
    track*, artist*: string
    album*, mbid*, albumArtist*: Option[string]
    timestamp*, trackNumber*, duration*: Option[int]

func newFMTrack*(
  artist, album: JsonNode,
  date: Option[JsonNode] = none(JsonNode),
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

func newAttributes*(
  nowplaying: string): Attributes =
  ## Create new `Attributes` object
  result.nowplaying = nowplaying

func newScrobble*(
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

proc getVal(node: JsonNode, index: string): Option[cstring] =
  let val = getStr node{index}
  result = to val

proc parseDate(date: Option[JsonNode]): Option[int] =
  ## convert `string` date to `Option[int]
  if isSome date:
    let val = getStr get(date){"uts"}
    if val.isEmptyOrWhitespace():
      result = some parseInt val
    else:
      result = none int

proc parseMbid(mbid: string): Option[seq[cstring]] =
  if mbid.isEmptyOrWhitespace():
    result = some @[cstring mbid]
  else:
    result = none seq[cstring]

proc to*(
  fmTrack: FMTrack,
  preMirror, mirrored: Option[bool] = none(bool)): Listen =
  ## Convert an `FMTrack` object to a `Listen` object
  result = newListen(trackName = cstring get fmTrack.name,
                    artistName = get getVal(fmTrack.artist, "#text"),
                    releaseName = getVal(fmTrack.album, "#text"),
                    recordingMbid = to fmTrack.mbid,
                    releaseMbid = getVal(fmTrack.album, "mbid"),
                    artistMbids = parseMbid getStr fmTrack.artist{"mbid"},
                    listenedAt = parseDate fmTrack.date,
                    preMirror = preMirror,
                    mirrored = mirrored)

proc to*(
  fmTracks: seq[FMTrack],
  preMirror, mirrored: Option[bool] = none(bool)): seq[Listen] =
  ## Convert a sequence of `FMTrack` objects to a sequence of `Listen` objects
  for fmTrack in fmTracks:
    result.add to(fmTrack, preMirror, mirrored)

proc to*(scrobble: Scrobble,
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

proc to*(
  listens: seq[Scrobble],
  preMirror, mirrored: Option[bool] = none(bool)): seq[Listen] =
  ## Convert a sequence of `Scrobble` objects to a sequence of `Listen` objects
  for listen in listens:
    result.add to(listen, preMirror, mirrored)

proc to*(listen: Listen): Scrobble =
  ## Convert a `Listen` object to a `Scrobble` object
  result = newScrobble(track = $listen.trackName,
                      artist = $listen.artistName,
                      timestamp = listen.listenedAt,
                      album = to listen.releaseName,
                      mbid = to listen.recordingMbid,
                      albumArtist = some $listen.artistName,
                      trackNumber = listen.trackNumber)

proc to*(tracks: seq[Listen], toMirror = false): seq[Scrobble] =
  ## Convert a sequence of `Listen` objects to a sequence of `Scrobble` objects.
  ## When `toMirror` is set, only tracks that have not been mirrored or are not pre-mirror are returned.
  for track in tracks:
    if toMirror:
      if not get(track.mirrored) and not get(track.preMirror):
        result.add to track
    else:
      result.add to track

proc getRecentTracks*(
  fm: AsyncLastFM,
  username: cstring,
  preMirror: bool,
  `from`, to = 0,
  limit = 7): Future[(Option[Listen], seq[Listen])] {.async.} =
  ## Return a Last.FM user's listen history and now playing
  var
    playingNow: Option[Listen]
    listenHistory: seq[Listen]
  let
    recentTracks = await fm.userRecentTracks(user = $username, limit = limit, `from` = `from`, to = to)
    tracks = recentTracks["recenttracks"]["track"]
  if tracks.len == limit:
    listenHistory = to fromJson($tracks, seq[FMTrack])
  elif tracks.len == limit+1:
    playingNow = some to(fromJson($tracks[0], FMTrack), preMirror = some preMirror)
    listenHistory = to(fromJson($tracks[1..^1], seq[FMTrack]), preMirror = some preMirror)
  result = (playingNow, listenHistory)

proc setNowPlayingTrack*(
  fm: AsyncLastFM,
  scrobble: Scrobble): Future[JsonNode] {.async.} =
  ## Sets the current playing track on Last.FM
  result = await fm.setNowPlaying(track = scrobble.track,
                                  artist = scrobble.artist,
                                  album = get scrobble.album,
                                  mbid = get scrobble.mbid,
                                  albumArtist = get scrobble.albumArtist,
                                  trackNumber = scrobble.trackNumber,
                                  duration = scrobble.duration)

proc scrobbleTrack*(
  fm: AsyncLastFM,
  scrobble: Scrobble): Future[JsonNode] {.async.} =
  ## Scrobble a track to Last.FM
  result = await fm.scrobble(track = scrobble.track,
                             artist = scrobble.artist,
                             timestamp = get scrobble.timestamp,
                             album = get scrobble.album,
                             mbid = get scrobble.mbid,
                             albumArtist = get scrobble.albumArtist,
                             trackNumber = scrobble.trackNumber,
                             duration = scrobble.duration)

proc scrobbleTracks*(
  fm: AsyncLastFM,
  scrobbles: seq[Scrobble]): Future[seq[JsonNode]] {.async.} =
  for scrobble in scrobbles:
    result.add await fm.scrobbleTrack(scrobble)

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
    (_, listenHistory) = await fm.getRecentTracks(user.services[lastFmService].username, preMirror = true, to = to)
  user.listenHistory = user.listenHistory & listenHistory
  endInd += inc

proc submitMirrorQueue*(
  fm: AsyncLastFM,
  user: var User) {.async.} =
  ## Submits user's now playing and listen history that are not mirrored or preMirror
  if isSome user.playingNow:
    try:
      discard fm.setNowPlayingTrack(to get user.playingNow)
    except HttpRequestError:
      echo "ERROR: There was a problem submitting your now playing!"

  let scrobbles = to(user.listenHistory, toMirror = true)
  if scrobbles.len > 0:
    try:
      discard fm.scrobbleTracks scrobbles
      let mirroredTracks = to scrobbles
      for idx, track in user.listenHistory[0..^1]:
        if track in mirroredTracks:
          user.listenHistory[idx].mirrored = some true
    except HttpRequestError:
      echo "ERROR: There was a problem submitting your scrobbles!"
