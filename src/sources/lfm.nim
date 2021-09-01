import std/[asyncdispatch, strutils, json]
import lastfm
import lastfm/[track, user]
include utils
import ../types


type
  FMTrack* = object
    artist*, album*: FMObject
    date*: Option[JsonNode]
    mbid*, name*, url*: string
    attr*: Option[Attributes]

  FMObject* = object
    text*, mbid*: string

  Attributes* = object
    nowplaying*: bool

  Scrobble* = object
    track*, artist*, album*, mbid*, albumArtist*: string
    trackNumber*, duration*: Option[int]


proc renameHook*(v: var FMTrack, fieldName: var string) =
  if fieldName == "@attr":
    fieldName = "attr"


proc renameHook*(v: var FMObject, fieldName: var string) =
  if fieldName == "#text":
    fieldName = "text"


proc parseHook*(s: string, i: var int, v: var bool) =
  var str: string
  parseHook(s, i, str)
  v = parseBool(str)


func newFMTrack*(
  artist, album: FMObject,
  date: Option[JsonNode] = none(JsonNode),
  mbid, name, url: string,
  attr: Option[Attributes] = none(Attributes)): FMTrack =
  ## Create new `FMTrack` object
  result.artist = artist
  result.album = album
  result.date = date
  result.mbid = mbid
  result.name = name
  result.url = url
  result.attr = attr

func newFMObject*(
  mbid, text: string = ""): FMObject =
  ## Create new `FMObject` object
  result.text = text
  result.mbid = mbid


func newAttributes*(
  nowplaying: bool): Attributes =
  ## Create new `Attributes` object
  result.nowplaying = nowplaying


func newScrobble*(
  track, artist: string,
  album, mbid, albumArtist: string = "",
  trackNumber, duration: Option[int] = none(int)): Scrobble =
  ## Create new `Scrobble` object
  result.track = track
  result.artist = artist
  result.album = album
  result.mbid = mbid
  result.albumArtist = albumArtist
  result.trackNumber = trackNumber
  result.duration = duration


proc to*(fmTrack: FMTrack): Track =
  ## Convert an `FMTrack` object to a `Track` object
  var date: Option[int64]
  if isSome(fmTrack.date):
    let dateStr = getStr(get(fmTrack.date){"uts"})
    if dateStr != "":
      date = some(parseBiggestInt(dateStr))
    else:
      date = none(int64)
  result = newTrack(trackName = fmTrack.name,
                    artistName = fmTrack.artist.text,
                    releaseName = fmTrack.album.text,
                    recordingMbid = fmTrack.mbid,
                    releaseMbid = fmTrack.album.mbid,
                    artistMbids = @[fmTrack.artist.mbid],
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
                    artistMbids = @[scrobble.mbid],
                    trackNumber = scrobble.trackNumber,
                    duration = scrobble.duration)


proc getRecentTracks*(
  fm: SyncLastFM | AsyncLastFM,
  user: User,
  limit: int = 7): Future[(Option[Track], seq[Track])] {.multisync.} =
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
  fm: SyncLastFM | AsyncLastFM,
  user: User) {.multisync.} =
  ## Update a Last.FM user's `playingNow` and `listenHistory`
  let tracks = await getRecentTracks(fm, user)
  user.playingNow = tracks[0]
  user.listenHistory = tracks[1]


proc setNowPlayingTrack*(
  fm: SyncLastFM | AsyncLastFM,
  scrobble: Scrobble): Future[JsonNode] {.multisync.} =
  ## Sets the current playing track on Last.FM
  result = await fm.setNowPlaying(track = scrobble.track,
                                  artist = scrobble.artist,
                                  album = scrobble.album,
                                  mbid = scrobble.mbid,
                                  albumArtist = scrobble.albumArtist,
                                  trackNumber = scrobble.trackNumber,
                                  duration = scrobble.duration)


proc scrobbleTrack*(
  fm: SyncLastFM | AsyncLastFM,
  scrob: Scrobble): Future[JsonNode] {.multisync.} =
  ## Scrobble a track to Last.FM
  result = await fm.scrobble(track = scrob.track,
                             artist = scrob.artist,
                             album = scrob.album,
                             mbid = scrob.mbid,
                             albumArtist = scrob.albumArtist,
                             trackNumber = scrob.trackNumber,
                             duration = scrob.duration)