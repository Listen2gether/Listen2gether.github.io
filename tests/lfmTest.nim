import std/[unittest, strutils]
include ../src/sources/lfm

suite "Last.FM source":
  setup:
    let
      jsonEx = readFile("tests/lfmEx.json")
      jsonNode = parseJson(jsonEx)

  test "jsony - json > FMTrack":
    let
      recentTracksJson = jsonNode["RecentTracks"]
      fmTrack = newFMTrack(
        artist = newFMObject(mbid = "", text = "Ryuichi Sakamoto"),
        album = newFMObject(mbid = "0f10b982-1be7-4eb9-94fe-0376ea99a980", text = "Esperanto"),
        date = some(parseJson("""{"uts": "1630429609", "#text": "31 Aug 2021, 17:06"}""")),
        mbid = "",
        name = "A Wongga Dance Song",
        url = "https://www.last.fm/music/Ryuichi+Sakamoto/_/A+Wongga+Dance+Song",
        attr = some(newAttributes(nowplaying = true)))
      fmTrackJson = $recentTracksJson["recenttracks"]["track"][0]
      fmTrackObj = fmTrackJson.fromJson(FMTrack)
    check fmTrack == fmTrackObj

  test "jsony - FMTrack > Track":
    let
      recentTracksJson = jsonNode["RecentTracks"]
      track = newTrack(
        trackName = "A Wongga Dance Song",
        artistName = "Ryuichi Sakamoto",
        releaseName = "Esperanto",
        recordingMbid = "",
        releaseMbid = "0f10b982-1be7-4eb9-94fe-0376ea99a980",
        artistMbids = @[],
        trackNumber = none(int),
        duration = none(int),
        listenedAt = some(parseBiggestInt("1630429609")))
      fmTrackObj = fromJson($recentTracksJson["recenttracks"]["track"][0], FMTrack)
      trackObj = to(fmTrackObj)
    check track == trackObj