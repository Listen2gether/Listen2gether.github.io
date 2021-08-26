import std/unittest
include ../src/sources/lfm

suite "Last.FM source":
  setup:
    let
      jsonEx = readFile("tests/lfmEx.json")
      recentTracksJson = parseJson(jsonEx)["recenttracks"]
      recentTracks = newFMTrack(
        artist = newFMObject(mbid = "", text = "Ryuichi Sakamoto"),
        album = newFMObject(mbid = "0f10b982-1be7-4eb9-94fe-0376ea99a980", text = "Esperanto"),
        mbid = "",
        name = "A Wongga Dance Song",
        url = "https://www.last.fm/music/Ryuichi+Sakamoto/_/A+Wongga+Dance+Song",
        attr = some(newAttributes(nowplaying = true)))

  test "jsony - FMTrack":
    let
      trackJson = $recentTracksJson["track"][0]
      trackObj = fromJson(trackJson, FMTrack)
    check recentTracks == trackObj