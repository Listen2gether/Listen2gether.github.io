import std/[unittest, os, asyncdispatch]
include ../src/sources/lb

suite "ListenBrainz source":

  suite "to Helpers":
    test "Convert some `Option[seq[cstring]]` to `Option[seq[string]]`":
      let
        cstringSeq: Option[seq[cstring]] = some @[cstring "test!", cstring "test?"]
        stringSeq: Option[seq[string]] = some @["test!", "test?"]
      check to(cstringSeq) == stringSeq

    test "Convert none `Option[seq[cstring]]` to `Option[seq[string]]`":
      let
        cstringSeq: Option[seq[cstring]] = none seq[cstring]
        stringSeq: Option[seq[string]] = none seq[string]
      check to(cstringSeq) == stringSeq

    test "Convert some `Option[seq[string]]` to `Option[seq[cstring]]`":
      let
        stringSeq: Option[seq[string]] = some @["test!", "test?"]
        cstringSeq: Option[seq[cstring]] = some @[cstring "test!", cstring "test?"]
      check to(stringSeq) == cstringSeq

    test "Convert none `Option[seq[string]]` to `Option[seq[cstring]]`":
      let
        stringSeq: Option[seq[string]] = none seq[string]
        cstringSeq: Option[seq[cstring]] = none seq[cstring]
      check to(stringSeq) == cstringSeq

    test "Convert some `Option[string]` to `Option[cstring]`":
      let
        str: Option[string] = some "test!"
        cstr: Option[cstring] = some cstring "test!"
      check to(str) == cstr

    test "Convert none `Option[string]` to `Option[cstring]`":
      let
        stringSeq: Option[string] = none string
        cstringSeq: Option[cstring] = none cstring
      check to(stringSeq) == cstringSeq

    test "Convert `Track` to `APIListen` (Simple)":
      let
        trackName = "track"
        artistName = "artist"
        track = newTrack(cstring trackName, cstring artistName)
        listenedAt = some 1
        apiListen = newAPIListen(listenedAt = listenedAt, trackMetadata = newTrackMetadata(trackName, artistName))
        newAPIListen = to(track, listenedAt)
      check newAPIListen.listenedAt == apiListen.listenedAt and newAPIListen.trackMetadata.trackName == apiListen.trackMetadata.trackName and newAPIListen.trackMetadata.artistName == apiListen.trackMetadata.artistName

    test "Convert `APIListen` to `Track` (Simple)":
      let
        trackName = "track"
        artistName = "artist"
        apiListen = newAPIListen(trackMetadata = newTrackMetadata(trackName, artistName))
        preMirror = some true
        track = newTrack(cstring trackName, cstring artistName, preMirror = preMirror)
        newTrack = to(apiListen, preMirror)
      check newTrack.trackName == track.trackName and newTrack.artistName == track.artistName and newTrack.preMirror == track.preMirror

    test "Convert `seq[APIListen]` to `seq[Track]` (Simple)":
      let
        apiListens = @[newAPIListen(trackMetadata = newTrackMetadata("track", "artist")), newAPIListen(trackMetadata = newTrackMetadata("track1", "artist1"))]
        tracks = @[newTrack(cstring "track", cstring "artist", mirrored = some false), newTrack(cstring "track1", cstring "artist1", mirrored = some false)]
        newTracks = to(apiListens)
      check newTracks == tracks

  suite "API tools":
    setup:
      let
        lb = newAsyncListenBrainz()
        username = cstring os.getEnv("LISTENBRAINZ_USER")
      var user = newUser(userId = username, services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username), Service.lastFmService: newServiceUser(Service.lastFmService)])

    test "Get now playing":
      discard lb.getNowPlaying(username)

    test "Get recent tracks":
      discard lb.getRecentTracks(username, user.lastUpdateTs, preMirror = false)

    test "Initialise user":
      discard lb.initUser(username)

    test "Update user":
      discard lb.updateUser(user)

