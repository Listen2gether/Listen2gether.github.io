import std/[unittest, os]
include ../src/sources/lfm

suite "Last.FM source":

  suite "Helpers":
    let
      scrobble = newScrobble(
        track = "鳴門海峡",
        artist = "Soichi Terada",
        album = some "Acid Face",
        mbid = some "recording-mbid",
        albumArtist = some "Soichi Terada",
        timestamp = some 0,
        trackNumber = some 3,
      )
      track: FMTrack = newFMTrack(
        artist = parseJson """{"mbid": "artist-mbid", "#text": "Soichi Terada"}""",
        album = parseJson """{"mbid": "album-mbid", "#text": "Acid Face"}""",
        date = some FMDate(uts: "0", text: ""),
        mbid = scrobble.mbid,
        name = some scrobble.track,
      )
      listen = newListen(
        trackName = cstring get track.name,
        artistName = cstring "Soichi Terada",
        releaseName = some cstring "Acid Face",
        recordingMbid = to track.mbid,
        releaseMbid = some cstring "release-mbid",
        artistMbids = some @[cstring "artist-mbid"],
        trackNumber = scrobble.trackNumber,
        listenedAt = scrobble.timestamp,
      )

    test "Convert `JsonNode` to `Option[cstring]`":
      check getVal(track.artist, "#text") == some(cstring "Soichi Terada")

    test "Convert `FMDate` to `Option[int]`":
      check parseDate(track.date) == some(0)

    test "Convert `string` to `Option[seq[cstring]]`":
      check parseMbids(get track.mbid) == some(@[cstring "recording-mbid"])

    test "Convert `FMTrack` to `Listen`":
      var newListen = listen
      newListen.trackNumber = none int
      check to(track) == newListen

    test "Convert `seq[FMTrack]` to `seq[Listen]`":
      var trackListen = listen
      trackListen.trackNumber = none int
      check to(@[track, track]) == @[trackListen, trackListen]

    test "Convert `Scrobble` to `Listen`":
      var newListen = listen
      newListen.releaseMbid = none cstring
      newListen.artistMbids = none seq[cstring]
      check to(scrobble) == newListen

    test "Convert `Scrobble` to `Listen` to `Scrobble`":
      check scrobble == to to scrobble

    test "Convert `seq[Scrobble]` to `seq[Listen]`":
      var newListen = listen
      newListen.releaseMbid = none cstring
      newListen.artistMbids = none seq[cstring]
      check to(@[scrobble, scrobble]) == @[newListen, newListen]

  suite "API tools":
    setup:
      let
        fm = newAsyncLastFM(apiKey, apiSecret)
        username = cstring os.getEnv("LASTFM_USER")

    test "Get recent tracks":
      let (nowplaying, recentTracks) = waitFor fm.getRecentTracks(username, preMirror = false)
      check recentTracks.len == 100

    test "Initialise user":
      let newUser = waitFor fm.initUser(username)

    test "Update user":
      var user = newUser(username, Service.lastFmService)
      let updatedUser = waitFor fm.updateUser(user)

    ## Cannot be tested outside JS backend
    # test "Page user":
    #   let inc = 10
    #   var endInt = 10
    #   discard lb.pageUser(user, endInt, inc)
    #   check endInt == 20

    ## Cannot be tested outside JS backend
    # test "Submit mirror queue":
    #   var user = newUser(id = username, services = [Service.listenBrainzService: newServiceUser(Service.listenBrainzService, username), Service.lastFmService: newServiceUser(Service.lastFmService)])
    #   user.listenHistory = @[newListen("track 1", "artist", preMirror = some false, mirrored = some false)]
    #   discard lb.submitMirrorQueue(user)