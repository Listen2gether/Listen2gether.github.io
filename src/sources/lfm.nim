when defined(js):
  import std/asyncjs
else:
  import std/asyncdispatch

import
  std/[json, options, strutils, times, unicode, sugar],
  pkg/[jsony, lastfm],
  pkg/lastfm/[track, user],
  types, utils, pure

const
  userBaseUrl*: cstring = "https://last.fm/user/"
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

func newFMTrack( artist, album: JsonNode, date: Option[FMDate] = none(FMDate), mbid, name, url: Option[string] = none(string), `@attr`: Option[Attributes] = none(Attributes)): FMTrack =
  ## Create new `FMTrack` object
  result.artist = artist
  result.album = album
  result.date = date
  result.mbid = mbid
  result.name = name
  result.url = url
  result.`@attr` = `@attr`

func `==`*(a, b: FMDate): bool = a.uts == b.uts and a.text == b.text

func `==`*(a, b: FMTrack): bool =
  return a.artist == b.artist and
    a.album == b.album and
    a.date == b.date and
    a.mbid == b.mbid and
    a.name == b.name and
    a.url == b.url and
    a.`@attr` == b.`@attr`

func newAttributes(nowplaying: string): Attributes =
  ## Create new `Attributes` object
  result.nowplaying = nowplaying

func `==`*(a, b: Attributes): bool = a.nowplaying == b.nowplaying

func newScrobble(track, artist: string, album, mbid, albumArtist: Option[string] = none(string), timestamp, trackNumber, duration: Option[int] = none(int)): Scrobble =
  ## Create new `Scrobble` object
  result.track = track
  result.artist = artist
  result.timestamp = timestamp
  result.album = album
  result.mbid = mbid
  result.albumArtist = albumArtist
  result.trackNumber = trackNumber
  result.duration = duration

func `==`*(a, b: Scrobble): bool =
  return a.track == b.track and
    a.artist == b.artist and
    a.timestamp == b.timestamp and
    a.album == b.album and
    a.mbid == b.mbid and
    a.albumArtist == b.albumArtist and
    a.trackNumber == b.trackNumber and
    a.duration == b.duration

func getVal(node: JsonNode, index: string): Option[cstring] = to getStr node{index}
  ## Get an `Option[cstring]` value from a `JsonNode` and `index`

func parseDate(date: Option[FMDate]): Option[int] =
  ## Convert `Option[FMDate]` date to `Option[int]
  if isSome date:
    result = some parseInt get(date).uts
  else:
    result = none int

func parseMbids(mbid: string): Option[seq[cstring]] =
  ## Convert `string` to `Option[seq[cstring]]`
  if isEmptyOrWhitespace mbid:
    result = none seq[cstring]
  else:
    result = some @[cstring mbid]

func to(fmTrack: FMTrack): Listen =
  ## Convert an `FMTrack` object to a `Listen` object
  result = newListen(trackName = cstring get fmTrack.name,
                    artistName = get getVal(fmTrack.artist, "#text"),
                    releaseName = getVal(fmTrack.album, "#text"),
                    recordingMbid = to fmTrack.mbid,
                    releaseMbid = getVal(fmTrack.album, "mbid"),
                    artistMbids = parseMbids getStr fmTrack.artist{"mbid"},
                    listenedAt = parseDate fmTrack.date)

func to(fmTracks: seq[FMTrack]): seq[Listen] =
  ## Convert a sequence of `FMTrack` objects to a sequence of `Listen` objects
  result = collect:
    for fmTrack in fmTracks:
      to(fmTrack)

func to(scrobble: Scrobble): Listen =
  ## Convert a `Scrobble` object to a `Listen` object
  result = newListen(trackName = cstring scrobble.track,
                    artistName = cstring scrobble.artist,
                    releaseName = to scrobble.album,
                    recordingMbid = to scrobble.mbid,
                    trackNumber = scrobble.trackNumber,
                    listenedAt = scrobble.timestamp)

func to(listens: seq[Scrobble]): seq[Listen] =
  ## Convert a sequence of `Scrobble` objects to a sequence of `Listen` objects
  result = collect:
    for listen in listens:
      to(listen)

func to(listen: Listen): Scrobble =
  ## Convert a `Listen` object to a `Scrobble` object
  result = newScrobble(track = $listen.trackName,
                      artist = $listen.artistName,
                      timestamp = listen.listenedAt,
                      album = to listen.releaseName,
                      mbid = to listen.recordingMbid,
                      albumArtist = some $listen.artistName,
                      trackNumber = listen.trackNumber)

func to(tracks: seq[Listen]): seq[Scrobble] =
  ## Convert a sequence of `Listen` objects to a sequence of `Scrobble` objects.
  result = collect:
    for track in tracks:
      to(track)

proc setNowPlayingTrack(fm: AsyncLastFM, scrobble: Scrobble): Future[JsonNode] {.async.} =
  ## Sets the current playing track on Last.fm
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

proc scrobbleTrack(fm: AsyncLastFM, scrobble: Scrobble): Future[JsonNode] {.async.} =
  ## Scrobble a track to Last.fm
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

proc scrobbleTracks(fm: AsyncLastFM, scrobbles: seq[Scrobble]): Future[seq[JsonNode]] {.async.} =
  ## Scrobble many tracks to Last.fm
  result = collect:
    for scrobble in scrobbles:
      await fm.scrobbleTrack(scrobble)

proc getRecentTracks(fm: AsyncLastFM, username: cstring, `from`, upTo = 0, limit = 100): Future[(Option[Listen], seq[Listen])] {.async.} =
  ## Return a Last.FM user's listen history and now playing
  var
    playingNow: Option[Listen]
    listenHistory: seq[Listen]
  try:
    let
      recentTracks = await fm.userRecentTracks(user = $username, limit = limit, `from` = `from`, to = upTo)
      tracks = recentTracks["recenttracks"]["track"]
    if tracks.len == limit:
      listenHistory = to(fromJson($tracks, seq[FMTrack]))
    elif tracks.len == limit+1:
      playingNow = some to(fromJson($tracks[0], FMTrack))
      listenHistory = to(fromJson($tracks[1..^1], seq[FMTrack]))
    return (playingNow, listenHistory)
  except HttpRequestError:
    logError "There was a problem getting " & $username & "'s listens!"

proc initUser*(fm: AsyncLastFM, username: cstring, sessionKey: cstring = "", selected = false): Future[User] {.async.} =
  ## Gets a given Last.fm user's now playing, recent tracks, and latest listen timestamp.
  ## Returns a `User` object
  let username = cstring toLower($username)
  var user = newUser(username, Service.lastFmService, sessionKey = sessionKey)
  user.lastUpdateTs = int toUnix getTime()
  let (playingNow, listenHistory) = await fm.getRecentTracks(username)
  user.playingNow = playingNow
  user.listenHistory = listenHistory

proc updateUser*(fm: AsyncLastFM, user: User, resetLastUpdate = false): Future[User] {.async.} =
  ## Updates Last.fm user's now playing, recent tracks, and latest listen timestamp

  var updatedUser = user
  if resetLastUpdate or user.listenHistory.len > 0:
    updatedUser.lastUpdateTs = get user.listenHistory[0].listenedAt
  else:
    updatedUser.lastUpdateTs = int toUnix getTime()

  if resetLastUpdate:
    let
      (_, latestListenHistory) = await fm.getRecentTracks(user.username)
      upTo = get latestListenHistory[^1].listenedAt

    if upTo > updatedUser.lastUpdateTs: # fills in any gaps in history
      var (playingNow, listenHistory) = await fm.getRecentTracks(user.username, `from` = user.lastUpdateTs, upTo = upTo)
      updatedUser.listenHistory = listenHistory & user.listenHistory
      while listenHistory.len > 0:
        (playingNow, listenHistory) = await fm.getRecentTracks(user.username, `from` = user.lastUpdateTs, upTo = upTo)
        updatedUser.listenHistory = listenHistory & updatedUser.listenHistory
      updatedUser.playingNow = playingNow
      updatedUser.listenHistory = latestListenHistory & updatedUser.listenHistory
    else: # no gap / overlap
      let (playingNow, listenHistory) = await fm.getRecentTracks(user.username, `from` = updatedUser.lastUpdateTs)
      updatedUser.playingNow = playingNow
      updatedUser.listenHistory = listenHistory & user.listenHistory
  else:
    let (playingNow, listenHistory) = await fm.getRecentTracks(user.username, `from` = user.lastUpdateTs)
    updatedUser.playingNow = playingNow
    updatedUser.listenHistory = listenHistory & user.listenHistory
  return updatedUser

proc pageUser*(fm: AsyncLastFM, user: var User, endInd: var int, `inc` = 10) {.async.} =
  ## Backfills Last.fm user's recent tracks
  let
    to = get user.listenHistory[^1].listenedAt
    (playingNow, listenHistory) = await fm.getRecentTracks(user.username, upTo = to)
  user.playingNow = playingNow
  user.listenHistory = user.listenHistory & listenHistory
  endInd += `inc`

proc submitMirrorQueue*(fm: AsyncLastFM, user: var User) {.async.} =
  ## Submits Last.fm user's now playing and listen history
  if user.submitQueue.playingNow.isSome():
    try:
      discard fm.setNowPlayingTrack(to get user.playingNow)
      user.submitQueue.playingNow = none Listen
    except HttpRequestError:
      logError("There was a problem submitting your now playing!")
  if user.submitQueue.listens.len > 0:
    try:
      discard fm.scrobbleTracks to(user.submitQueue.listens)
      user.lastSubmissionTs = user.submitQueue.listens[0].listenedAt
      user.submitQueue.listens = @[]
    except:
      logError "There was a problem submitting your scrobbles!"
