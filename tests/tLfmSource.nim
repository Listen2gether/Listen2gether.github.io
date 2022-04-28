import std/[unittest, asyncdispatch, options, json]
include ../src/sources/lfm

suite "Last.FM source":

  suite "Helpers":
    let track: FMTrack = newFMTrack(
      artist = parseJson """{"mbid": "fabc9908-3a4a-4c79-86bd-1f7e4506b0d8", "#text": "Soichi Terada"}""",
      album = parseJson """{"mbid": "e07d5174-6181-498f-88fb-b92833bb81de", "#text": "Acid Face"}""",
      date = some FMDate(uts: "0", text: ""),
      mbid = some "fabc9908-3a4a-4c79-86bd-1f7e4506b0d8",
      name = some "鳴門海峡",
      url = some "https://www.last.fm/music/Soichi+Terada/_/%E9%B3%B4%E9%96%80%E6%B5%B7%E5%B3%A1",
      `@attr` = none Attributes
    )

    test "Convert JsonNode to Option[cstring]":
      check getVal(track.artist, "#text") == some(cstring "Soichi Terada")

    test "Convert FMDate to Option[int]":
      check parseDate(track.date) == some(0)

    test "Convert Mbids to Option[seq[cstring]]":
      check parseMbids(get track.mbid) == some(@[cstring "fabc9908-3a4a-4c79-86bd-1f7e4506b0d8"])

    test "Convert FMTrack to Listen":
      let listen = newListen(
        trackName = cstring get track.name,
        artistName = get getVal(track.artist, "#text"),
        releaseName = getVal(track.album, "#text"),
        recordingMbid = to track.mbid,
        releaseMbid = getVal(track.album, "mbid"),
        artistMbids = parseMbids getStr track.artist{"mbid"},
        listenedAt = parseDate track.date
      )
      check to(track) == listen
