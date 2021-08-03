import asyncdispatch, options, json, strutils
include lastfm
import lastfm / [track, user]
import options
include utils
import ../types


type
  FMTrack* = ref object
    artist*, album*: FMObject
    mbid*, name*, url*: string
    streamable*: bool
    attr: Option[Attributes]

  FMObject* = ref object
    mbid*, text*: string

  Attributes* = ref object
    nowplaying*: bool

  Scrobble* = ref object
    track*, artist*: string
    album*, mbid*, albumArtist*: Option[string]
    trackNumber*, duration*: Option[int]


func newFMTrack*(
  artist, album: FMObject,
  mbid, name, url: string,
  streamable: bool,
  attr: Option[Attributes] = none(Attributes)): FMTrack =
  ## Create new `FMTrack` object
  new(result)
  result.artist = artist
  result.album = album
  result.mbid = mbid
  result.name = name
  result.url = url
  result.streamable = streamable
  result.attr = attr


func newFMObject*(
  mbid, text: string): FMObject =
  ## Create new `FMObject` object
  new(result)
  result.mbid = mbid
  result.text = text


func newAttributes*(
  nowplaying: bool): Attributes =
  new(result)
  result.nowplaying = nowplaying


func newScrobble*(
  track, artist: string,
  album, mbid, albumArtist: Option[string] = none(string),
  trackNumber, duration: Option[int] = none(int)): Scrobble =
  ## Create new `Scrobble` object
  new(result)
  result.track = track
  result.artist = artist
  result.album = album
  result.mbid = mbid
  result.albumArtist = albumArtist
  result.trackNumber = trackNumber
  result.duration = duration


proc to*(fmTrack: FMTrack): Track =
  ## Convert an `FMTrack` to a `Track`
  result = newTrack(trackName = fmTrack.name,
                    artistName = fmTrack.artist.text,
                    releaseName = some(fmTrack.album.text),
                    recordingMbid = some(fmTrack.mbid),
                    releaseMbid = some(fmTrack.album.mbid),
                    artistMbids = some(@[fmTrack.artist.mbid]))


proc to*(scrobble: Scrobble): Track =
  ## Convert an `Scrobble` to a `Track`
  result = newTrack(trackName = scrobble.track,
                    artistName = scrobble.artist,
                    releaseName = scrobble.album,
                    artistMbids = some(@[get(scrobble.mbid)]),
                    trackNumber = scrobble.trackNumber,
                    duration = scrobble.duration)


proc getRecentTracks*(
  fm: SyncLastFM | AsyncLastFM,
  user: User) {.multisync.} =
  ## Get now playing for a Last.FM user
  let
    recentTracks = await fm.userRecentTracks(user = user.username, limit = 1)
    tracks = recentTracks["track"]
  if tracks.len == 1:
    user.lastPlayed = some(to(fromJson($tracks[0], FMTrack)))
  elif tracks.len == 2:
    user.playingNow = some(to(fromJson($tracks[0], FMTrack)))
    user.lastPlayed = some(to(fromJson($tracks[1], FMTrack)))
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