import std/[json, options]


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