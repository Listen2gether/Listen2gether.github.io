when defined(js):
  import std/[asyncjs, json, strutils, jsconsole, options]
  # import karax/indexeddb
  import listenbrainz, jsony
  import listenbrainz/core
  import lbTypes
  import utils
  import ../types
else:
  import std/[asyncdispatch, json, strutils, options]
  import listenbrainz, jsony
  import listenbrainz/core
  import lbTypes
  import utils
  import ../types


proc to*(
  track: Track,
  listenedAt: Option[int64]): Listen =
  ## Convert a `Track` object to a `Listen` object
  let
    additionalInfo = newAdditionalInfo(tracknumber = track.trackNumber,
                                       trackMbid = track.recordingMbid,
                                       recordingMbid = track.recordingMbid,
                                       releaseMbid = track.releaseMbid,
                                       artistMbids = track.artistMbids)
    trackMetadata = newTrackMetadata(trackName = track.trackName,
                                     artistName = track.artistName,
                                     releaseName = track.releaseName,
                                     additionalInfo = some(additionalInfo))
  result = newListen(listenedAt = listenedAt,
                     trackMetadata = trackMetadata)


proc to*(listen: Listen): Track =
  ## Convert a `Listen` object to a `Track` object
  result = newTrack(trackName = listen.trackMetadata.trackName,
                    artistName = listen.trackMetadata.artistName,
                    releaseName = listen.trackMetadata.releaseName,
                    recordingMbid = get(listen.trackMetadata.additionalInfo).recordingMbid,
                    releaseMbid = get(listen.trackMetadata.additionalInfo).releaseMbid,
                    artistMbids = get(listen.trackMetadata.additionalInfo).artistMbids,
                    trackNumber = get(listen.trackMetadata.additionalInfo).trackNumber,
                    listenedAt = listen.listenedAt)


proc to*(listens: seq[Listen]): seq[Track] =
  ## Convert a sequence of `Listen` objects to a sequence of `Track` objects
  for listen in listens:
    result.add(to(listen))


proc to*(
  listenPayload: ListenPayload,
  listenType: string): SubmissionPayload =
  ## Convert a `ListenPayload` object to a `SubmissionPayload` object
  result = newSubmissionPayload(listenType, listenPayload.listens)


proc validateLbToken*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  lbToken: string) {.multisync.} =
  ## Validate a ListenBrainz token given a ListenBrainz object and token
  if lbToken != "":
    let result = await lb.validateToken(lbToken)
    if result["code"].getInt != 200:
      raise newException(ValueError, "ERROR: Invalid token (or perhaps you are rate limited)")
  else:
    raise newException(ValueError, "ERROR: Token is empty string.")


proc getNowPlaying*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  user: User): Future[Option[Track]] {.multisync.} =
  ## Return a ListenBrainz user's now playing
  let
    nowPlaying = await lb.getUserPlayingNow(user.services[listenBrainzService].username)
  when defined(js):
    console.log($nowPlaying["payload"])
  let payload = fromJson($nowPlaying["payload"], ListenPayload)
  if payload.count == 1:
    result = some(to(payload.listens[0]))
  else:
    result = none(Track)


proc getRecentTracks*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  user: User,
  count: int = 7): Future[seq[Track]] {.multisync.} =
  ## Return a ListenBrainz user's listen history
  var tracks: seq[Track]
  let
    recentListens = await lb.getUserListens(user.services[listenBrainzService].username, count = count)
    payload = fromJson($recentListens["payload"], ListenPayload)
  if payload.count > 0:
    result = to(payload.listens)
  else:
    result = tracks


proc updateUser*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  user: User) {.multisync.} =
  ## Update a ListenBrainz user's `playingNow` and `listenHistory`
  user.playingNow = await getNowPlaying(lb, user)
  user.listenHistory = await getRecentTracks(lb, user)
  # let
  #   json = """{
  #   "count": 1,
  #   "latest_listen_ts": 1631565896,
  #   "listens": [
  #     {
  #       "inserted_at": "Mon, 13 Sep 2021 21:05:00 GMT",
  #       "listened_at": 1631565896,
  #       "recording_msid": "37a9a609-922c-4309-9236-7fe619588a0a",
  #       "track_metadata": {
  #         "additional_info": {
  #           "artist_mbids": [
  #             "b2853652-db74-44b7-b4b3-ffb72af6b910"
  #           ],
  #           "artist_msid": "546c1e23-e080-42bb-9146-82dfeebf0de0",
  #           "listening_from": "Lollypop",
  #           "recording_mbid": "9b1db701-fd8d-4996-b40f-5b24c6a17e78",
  #           "recording_msid": "37a9a609-922c-4309-9236-7fe619588a0a",
  #           "release_mbid": "2e326aa2-c7fa-4766-94bf-365e946b256f",
  #           "release_msid": "b5c45f6b-38d3-42f4-847d-ff49ae994a12",
  #           "tracknumber": 7
  #         },
  #         "artist_name": "Casiopea",
  #         "release_name": "Casiopea",
  #         "track_name": "Dream Hill"
  #       },
  #       "user_name": "tandy1000"
  #     }
  #   ],
  #   "user_id": "tandy1000"
  # }"""
  # # when defined(js):
  # #   console.log(json)
  # let listenPayload = fromJson(json, ListenPayload)
  # user.playingNow = some(to(listenPayload.listens[0]))
  # user.listenHistory = to(listenPayload.listens)  


proc listenTrack*(
  lb: SyncListenBrainz | AsyncListenBrainz,
  listenPayload: ListenPayload,
  listenType: string): Future[JsonNode] {.multisync.} =
  ## Submit a listen to ListenBrainz
  let
    payload = to(listenPayload, listenType)
    jsonBody = parseJson(payload.toJson())
  result = await lb.submitListens(jsonBody)