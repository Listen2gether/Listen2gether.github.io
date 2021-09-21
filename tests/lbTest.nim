import std/[unittest, options, json]
import jsony
import ../src/sources/[lb, lbTypes, utils]


suite "ListenBrainz source":
  setup:
    let
      jsonEx = readFile("tests/lbEx.json")
      jsonNode = parseJson(jsonEx)

  test "jsony - ListenPayload 1":
    let
      listenPayloadJson = jsonNode["listenPayload1"]
      listenPayload = newListenPayload(
        count = 1,
        listens = @[newListen(trackMetadata = newTrackMetadata(
          trackName = "Mais Que Amor",
          artistName = "Marcos Valle",
          releaseName = "Marcos Valle",
          additionalInfo = some(newAdditionalInfo(
            listeningFrom = "Player",
            trackMbid = "9f7b866c-49e8-4126-96de-f42cab2cbd4f",
            recordingMbid = "c0671f4d-b9c3-432c-909c-4e27c734c950",
            releaseMbid = "21484f51-09b4-4c6b-855d-a6f3874a23ce",
            artistMbids = @["1ba347eb-58e8-45d6-b7e3-09873dc2506a"]))))],
        playingNow = some(true))
      payloadJson = listenPayloadJson["payload"]
      payloadObj = fromJson($payloadJson, ListenPayload)
      objJson = toJson(payloadObj)
    check listenPayload == payloadObj
    check objJson == $payloadJson

  test "jsony - ListenPayload 2":
    let
      listenPayloadJson = jsonNode["listenPayload2"]
      listenPayload = newListenPayload(
        count = 1,
        listens = @[newListen(trackMetadata = newTrackMetadata(
          trackName = "Possibly Maybe",
          artistName = "Björk",
          releaseName = "Post",
          additionalInfo = some(newAdditionalInfo(
            listeningFrom = "Player",
            tracknumber = some(8),
            recordingMbid = "a6287b52-f085-4548-8c60-2740af19b3d7",
            releaseMbid = "0119ac37-0ba6-490a-ac2f-c04b38b09164",
            artistMbids = @["87c5dedd-371d-4a53-9f7f-80522fb7f3cb"]))))],
        playingNow = some(true))
      payloadJson = listenPayloadJson["payload"]
      payloadObj = fromJson($payloadJson, ListenPayload)
      objJson = toJson(payloadObj)
    check listenPayload == payloadObj
    check objJson == $payloadJson