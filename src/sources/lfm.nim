when defined(js):
  import std/asyncjs
else:
  import std/asyncdispatch
  import ../models

import std/[json, strutils]
import pkg/lastfm
import pkg/lastfm/[track, user]
import ../types
include utils


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
    trackNumber*, duration*: Option[int]


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
  trackNumber, duration: Option[int] = none(int)): Scrobble =
  ## Create new `Scrobble` object
  result.track = track
  result.artist = artist
  result.album = album
  result.mbid = mbid
  result.albumArtist = albumArtist
  result.trackNumber = trackNumber
  result.duration = duration


proc checkString(val: string): Option[string] =
  if val.isEmptyOrWhitespace():
    result = none(string)
  else:
    result = some(val)


proc getVal(node: JsonNode, index: string): Option[string] =
  let val = getStr(node{index})
  result = checkString(val)


proc to*(fmTrack: FMTrack): Track =
  ## Convert an `FMTrack` object to a `Track` object
  var
    date: Option[int64]
    artistMbid: string
    artistMbids: Option[seq[string]]
  if isSome(fmTrack.date):
    let dateStr = getStr(get(fmTrack.date){"uts"})
    if dateStr != "":
      date = some(parseBiggestInt(dateStr))
    else:
      date = none(int64)
  artistMbid = getStr(fmTrack.artist{"mbid"})
  if artistMbid != "":
    artistMbids = some(@[artistMbid])
  else:
    artistMbids = none(seq[string])
  result = newTrack(trackName = get(fmTrack.name),
                    artistName = get(getVal(fmTrack.artist, "#text")),
                    releaseName = getVal(fmTrack.album, "#text"),
                    recordingMbid = checkString(get(fmTrack.mbid)),
                    releaseMbid = getVal(fmTrack.album, "mbid"),
                    artistMbids = artistMbids,
                    listenedAt = date)


proc to*(fmTracks: seq[FMTrack]): seq[Track] =
  ## Convert a sequence of `FMTrack` objects to a sequence of `Track` objects
  for fmTrack in fmTracks:
    result.add(to(fmTrack))


proc to*(scrobble: Scrobble): Track =
  ## Convert an `Scrobble` object to a `Track` object
  result = newTrack(trackName = scrobble.track,
                    artistName = scrobble.artist,
                    releaseName = scrobble.album,
                    artistMbids = some(@[get(scrobble.mbid)]),
                    trackNumber = scrobble.trackNumber,
                    duration = scrobble.duration)


proc getRecentTracks*(
  fm: AsyncLastFM,
  user: User,
  limit: int = 7): Future[(Option[Track], seq[Track])] {.async.} =
  ## Return a Last.FM user's listen history and now playing
  var
    playingNow: Option[Track]
    listenHistory: seq[Track]
  let
    recentTracks = await fm.userRecentTracks(user = user.services[lastFmService].username, limit = limit)
    tracks = recentTracks["recenttracks"]["track"]
  if tracks.len == limit:
    listenHistory = to(fromJson($tracks, seq[FMTrack]))
  elif tracks.len == limit+1:
    playingNow = some(to(fromJson($tracks[0], FMTrack)))
    listenHistory = to(fromJson($tracks[1..^1], seq[FMTrack]))
  result = (playingNow, listenHistory)


proc updateUser*(
  fm: AsyncLastFM,
  user: User,
  preMirror: bool) {.async.} =
  ## Update a Last.FM user's `playingNow` and `listenHistory`
  let tracks = waitFor getRecentTracks(fm, user)
  user.playingNow = tracks[0]
  user.listenHistory = tracks[1]
  updateUserTable(user, lastFmService)


proc setNowPlayingTrack*(
  fm: AsyncLastFM,
  scrobble: Scrobble): Future[JsonNode] {.async.} =
  ## Sets the current playing track on Last.FM
  result = await fm.setNowPlaying(track = scrobble.track,
                                  artist = scrobble.artist,
                                  album = get(scrobble.album),
                                  mbid = get(scrobble.mbid),
                                  albumArtist = get(scrobble.albumArtist),
                                  trackNumber = scrobble.trackNumber,
                                  duration = scrobble.duration)


proc scrobbleTrack*(
  fm: AsyncLastFM,
  scrob: Scrobble): Future[JsonNode] {.async.} =
  ## Scrobble a track to Last.FM
  result = await fm.scrobble(track = scrob.track,
                             artist = scrob.artist,
                             album = get(scrob.album),
                             mbid = get(scrob.mbid),
                             albumArtist = get(scrob.albumArtist),
                             trackNumber = scrob.trackNumber,
                             duration = scrob.duration)
