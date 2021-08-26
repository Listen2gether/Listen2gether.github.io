import asyncdispatch, options, json, strutils
include lastfm
include utils
import ../types


type
  FMTrack* = object
    artist*, album*: FMObject
    mbid*, name*, url*: string
    attr: Option[Attributes]

  FMObject* = object
    mbid*, text*: string

  Attributes* = object
    nowplaying*: bool

  Scrobble* = object
    track*, artist*, album*, mbid*, albumArtist*: string
    trackNumber*, duration*: Option[int]

  Node = ref object
    kind: string


proc renameHook*(v: var Node, fieldName: var string) =
  if fieldName == "@attr":
    fieldName = "attr"
  elif fieldName == "#text":
    fieldName = "text"


proc parseHook*(s: string, i: var int, v: var bool) =
  var str: string
  parseHook(s, i, str)
  v = parseBool(str)


func newFMTrack*(
  artist, album: FMObject,
  mbid, name, url: string,
  attr: Option[Attributes] = none(Attributes)): FMTrack =
  ## Create new `FMTrack` object
  result.artist = artist
  result.album = album
  result.mbid = mbid
  result.name = name
  result.url = url
  result.attr = attr


func newFMObject*(
  mbid, text: string): FMObject =
  ## Create new `FMObject` object
  result.mbid = mbid
  result.text = text


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
  result = newTrack(trackName = fmTrack.name,
                    artistName = fmTrack.artist.text,
                    releaseName = fmTrack.album.text,
                    recordingMbid = fmTrack.mbid,
                    releaseMbid = fmTrack.album.mbid,
                    artistMbids = @[fmTrack.artist.mbid])


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
  limit: int = 10) {.multisync.} =
  ## Get now playing and listen history for a Last.FM user
  let
    recentTracks = await fm.userRecentTracks(user = user.services[lastFmService].username, limit = limit)
    tracks = recentTracks["recenttracks"]["track"]
    nowPlaying = parseBool($tracks[0]["@attr"]["nowplaying"])
  if tracks.len == limit:
    if nowPlaying:
      user.playingNow = some(to(fromJson($tracks[0], FMTrack)))
    else:
      user.listenHistory = to(fromJson($tracks, seq[FMTrack]))
  elif tracks.len == limit+1:
    user.playingNow = some(to(fromJson($tracks[0], FMTrack)))
    user.listenHistory = to(fromJson($tracks[1..^1], seq[FMTrack]))
  else:
    echo "User has no recent tracks!"


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