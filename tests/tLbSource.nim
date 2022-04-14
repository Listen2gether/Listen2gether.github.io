import std/[unittest, os, asyncdispatch, options]
include ../src/sources/lb

suite "ListenBrainz source":

  suite "to Helpers":

    test "Convert `Listen` to `APIListen` (Simple)":
      let
        trackName = "track"
        artistName = "artist"
        listenedAt = some 1
        track = newListen(cstring trackName, cstring artistName, listenedAt = listenedAt)
        apiListen = newAPIListen(listenedAt = listenedAt, trackMetadata = newTrackMetadata(trackName, artistName))
        newAPIListen = to track
      check newAPIListen.listenedAt == apiListen.listenedAt
      check newAPIListen.trackMetadata.trackName == apiListen.trackMetadata.trackName
      check newAPIListen.trackMetadata.artistName == apiListen.trackMetadata.artistName

    test "Convert `seq[Listen]` to `seq[APIListen]` (Simple)":
      let
        trackName = "track"
        artistName = "artist"
        listenedAt = some 1
        tracks = @[newListen(cstring trackName, cstring artistName, listenedAt = listenedAt)]
        apiListens = @[newAPIListen(listenedAt = listenedAt, trackMetadata = newTrackMetadata(trackName, artistName))]
        newAPIListens = to tracks
      check newAPIListens[0].listenedAt == apiListens[0].listenedAt
      check newAPIListens[0].trackMetadata.trackName == apiListens[0].trackMetadata.trackName
      check newAPIListens[0].trackMetadata.artistName == apiListens[0].trackMetadata.artistName

    test "Convert `Listen` to `APIListen` to `Listen`":
      let
        trackName = "track"
        artistName = "artist"
        listenedAt = some 1
        track = newListen(cstring trackName, cstring artistName, listenedAt = listenedAt)
        apiListen = to track
        newListen = to apiListen
      check newListen.trackName == track.trackName
      check newListen.artistName == track.artistName
      check newListen.releaseName == track.releaseName
      check newListen.recordingMbid == track.recordingMbid
      check newListen.releaseMbid == track.releaseMbid
      check newListen.artistMbids == track.artistMbids
      check newListen.trackNumber == track.trackNumber
      check newListen.listenedAt == track.listenedAt
      check newListen.mirrored == track.mirrored
      check newListen.preMirror == track.preMirror

    test "Convert `APIListen` to `Listen` (Simple)":
      let
        trackName = "track"
        artistName = "artist"
        apiListen = newAPIListen(trackMetadata = newTrackMetadata(trackName, artistName))
        preMirror = some true
        track = newListen(cstring trackName, cstring artistName, preMirror = preMirror)
        newListen = to(apiListen, preMirror)
      check newListen.trackName == track.trackName
      check newListen.artistName == track.artistName
      check newListen.preMirror == track.preMirror

    test "Convert `seq[APIListen]` to `seq[Listen]` (Simple)":
      let
        apiListens = @[newAPIListen(trackMetadata = newTrackMetadata("track", "artist")), newAPIListen(trackMetadata = newTrackMetadata("track1", "artist1"))]
        tracks = @[newListen(cstring "track", cstring "artist"), newListen(cstring "track1", cstring "artist1")]
        newTracks = to(apiListens)
      check newTracks == tracks

    test "Convert `APIListen` to `Listen` to `APIListen`":
      let
        trackName = "track"
        artistName = "artist"
        apiListen = newAPIListen(trackMetadata = newTrackMetadata(trackName, artistName))
        preMirror = some true
        track = to(apiListen, preMirror)
        newAPIListen = to track
      check newAPIListen.listenedAt == apiListen.listenedAt
      check  newAPIListen.insertedAt == apiListen.insertedAt
      check newAPIListen.userName == apiListen.userName
      check newAPIListen.listenedAtIso == apiListen.listenedAtIso
      check newAPIListen.recordingMsid == apiListen.recordingMsid
      check newAPIListen.playingNow == apiListen.playingNow
      check newAPIListen.trackMetadata.trackName == apiListen.trackMetadata.trackName
      check newAPIListen.trackMetadata.artistName == apiListen.trackMetadata.artistName
      check newAPIListen.trackMetadata.releaseName == apiListen.trackMetadata.releaseName
      check get(newAPIListen.trackMetadata.additionalInfo, AdditionalInfo()).recordingMbid == get(apiListen.trackMetadata.additionalInfo, AdditionalInfo()).recordingMbid
      check get(newAPIListen.trackMetadata.additionalInfo, AdditionalInfo()).releaseMbid == get(apiListen.trackMetadata.additionalInfo, AdditionalInfo()).releaseMbid
      check get(newAPIListen.trackMetadata.additionalInfo, AdditionalInfo()).artistMbids == get(apiListen.trackMetadata.additionalInfo, AdditionalInfo()).artistMbids
      check get(newAPIListen.trackMetadata.additionalInfo, AdditionalInfo()).tracknumber == get(apiListen.trackMetadata.additionalInfo, AdditionalInfo()).tracknumber

  suite "API tools":
    setup:
      let
        lb = newAsyncListenBrainz()
        username = cstring os.getEnv("LISTENBRAINZ_USER")

    test "Get now playing":
      let nowPlaying = waitFor lb.getNowPlaying(username, preMirror = false)

    test "Get recent tracks":
      let recentTracks = waitFor lb.getRecentTracks(username, preMirror = false)
      check recentTracks.len == 100

    test "Initialise user":
      let newUser = waitFor lb.initUser(username)

    test "Update user":
      var user = newUser(userId = username, services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username), Service.lastFmService: newServiceUser(Service.lastFmService)])
      let updatedUser = waitFor lb.updateUser(user)

    ## Cannot be tested outside JS backend
    # test "Page user":
    #   let inc = 10
    #   var endInt = 10
    #   discard lb.pageUser(user, endInt, inc)
    #   check endInt == 20

    ## Cannot be tested outside JS backend
    # test "Submit mirror queue":
    #   var user = newUser(userId = username, services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username), Service.lastFmService: newServiceUser(Service.lastFmService)])
    #   user.listenHistory = @[newListen("track 1", "artist", preMirror = some false, mirrored = some false)]
    #   discard lb.submitMirrorQueue(user)
