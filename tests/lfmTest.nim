import std/unittest
include ../src/sources/lfm
import print

suite "Last.FM source":
  setup:
    let
      jsonEx = readFile("tests/lfmEx.json")
      jsonNode = parseJson(jsonEx)

  test "jsony - FMTrack":
    let
      recentTracksJson = jsonNode["RecentTracks"]
      fmTrack = newFMTrack(
        artist = newFMObject(mbid = "", text = "Ryuichi Sakamoto"),
        album = newFMObject(mbid = "0f10b982-1be7-4eb9-94fe-0376ea99a980", text = "Esperanto"),
        mbid = "",
        name = "A Wongga Dance Song",
        url = "https://www.last.fm/music/Ryuichi+Sakamoto/_/A+Wongga+Dance+Song",
        attr = some(newAttributes(nowplaying = true)))
      fmTrackJson = $recentTracksJson["recenttracks"]["track"][0]
      fmTrackObj = fmTrackJson.fromJson(FMTrack)
    check fmTrack == fmTrackObj