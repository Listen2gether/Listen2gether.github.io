import std/unittest
include ../src/sources/lb

suite "ListenBrainz source":   
  setup:
    let
      jsonEx = readFile("tests/lbEx.json")
      jsonNode = parseJson(jsonEx)

  test "jsony - ListenPayload":
    let
      listenPayloadJson = jsonNode["listenPayload"]
      listenPayload = newListenPayload(
        count = 1,
        latestListenTs = none(int),
        listens = @[newListen(trackMetadata = newTrackMetadata(
          trackName = "Mais Que Amor",
          artistName = "Marcos Valle",
          releaseName = "Marcos Valle",
          additionalInfo = some(newAdditionalInfo(
            trackMbid = "9f7b866c-49e8-4126-96de-f42cab2cbd4f",
            recordingMbid = "c0671f4d-b9c3-432c-909c-4e27c734c950",
            releaseMbid = "21484f51-09b4-4c6b-855d-a6f3874a23ce",
            artistMbids = @["1ba347eb-58e8-45d6-b7e3-09873dc2506a"]))))],
        playingNow = some(true),
        userId = "test")
      payloadJson = listenPayloadJson["payload"]
      payloadObj = fromJson($payloadJson, ListenPayload)
    check listenPayload == payloadObj