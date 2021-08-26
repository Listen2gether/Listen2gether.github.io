import std/unittest
include ../src/sources/lfm

suite "jsony":
  setup:
    let
      jsonEx = readFile("tests/ex.json")
      lastFmRecentTracksJson = parseJson(jsonEx)["recenttracks"]
      lastFmRecentTracks = newFMTrack(artist = newFMObject(mbid = "", text = "Ryuichi Sakamoto"),
                                      album = newFMObject(mbid = "0f10b982-1be7-4eb9-94fe-0376ea99a980", text = "Esperanto"),
                                      mbid = "",
                                      name = "A Wongga Dance Song",
                                      url = "https://www.last.fm/music/Ryuichi+Sakamoto/_/A+Wongga+Dance+Song",
                                      attr = some(newAttributes(nowplaying = true)))

  test "lastFmRecentTracks":
    let
      trackJson = $lastFmRecentTracksJson["track"][0]
      trackObj = fromJson(trackJson, FMTrack)
    check lastFmRecentTracks == trackObj