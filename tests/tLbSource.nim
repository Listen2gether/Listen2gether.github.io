import std/[unittest, os]
include ../src/sources/lb

suite "ListenBrainz source":

  suite "Helpers":
    setup:
      let
        trackName = "track"
        artistName = "artist"
        listenedAt = some 1

    test "Convert `Listen` to `APIListen` (Simple)":
      let
        listen = newListen(cstring trackName, cstring artistName, listenedAt = listenedAt)
        apiListen = newAPIListen(listenedAt = listenedAt, trackMetadata = newTrackMetadata(trackName, artistName))
        newAPIListen = to listen
      check newAPIListen == apiListen

    test "Convert `seq[Listen]` to `seq[APIListen]` (Simple)":
      let
        listens = @[newListen(cstring trackName, cstring artistName, listenedAt = listenedAt)]
        apiListens = @[newAPIListen(listenedAt = listenedAt, trackMetadata = newTrackMetadata(trackName, artistName))]
        newAPIListens = to listens
      check newAPIListens[0] == apiListens[0]

    test "Convert `Listen` to `APIListen` to `Listen`":
      let
        listen = newListen(cstring trackName, cstring artistName, listenedAt = listenedAt)
        apiListen = to listen
        newListen = to apiListen
      check listen == newListen

    test "Convert `APIListen` to `Listen` (Simple)":
      let
        apiListen = newAPIListen(trackMetadata = newTrackMetadata(trackName, artistName))
        preMirror = some true
        listen = newListen(cstring trackName, cstring artistName, preMirror = preMirror)
        newListen = to(apiListen, preMirror)
      check listen == newListen

    test "Convert `seq[APIListen]` to `seq[Listen]` (Simple)":
      let
        apiListens = @[newAPIListen(trackMetadata = newTrackMetadata("track", "artist")), newAPIListen(trackMetadata = newTrackMetadata("track1", "artist1"))]
        listens = @[newListen(cstring "track", cstring "artist"), newListen(cstring "track1", cstring "artist1")]
        newListens = to(apiListens)
      check newListens == listens

    test "Convert `APIListen` to `Listen` to `APIListen`":
      let
        apiListen = newAPIListen(trackMetadata = newTrackMetadata(trackName, artistName))
        preMirror = some true
        listen = to(apiListen, preMirror)
        newAPIListen = to listen
      check apiListen == newAPIListen

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
