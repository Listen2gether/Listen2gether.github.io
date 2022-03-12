import
  pkg/karax/[karaxdsl, vdom],
  std/[times, options],
  ../sources/[lb],
  ../types, share

proc renderListens*(playingNow: Option[Track], listenHistory: seq[Track], maxListens: int = 6): Vnode =
  var
    trackName, artistName: cstring
    preMirrorSplit: bool = false

  result = buildHtml:
    tdiv(class = "listens"):
      ul:
        if isSome playingNow:
          li(class = "row listen"):
            tdiv(id = "listen-details"):
              img(src = "/assets/nowplaying.svg")
              tdiv(id = "track-details"):
                trackName = get(playingNow).trackName
                artistName = get(playingNow).artistName
                p(title = trackName, id = "track-name"):
                  text trackName
                p(title = artistName, id = "artist-name"):
                  text artistName
              span:
                text "Playing now"
        # for idx, track in listenHistory[0..maxListens]:
        #   if isSome(track.preMirror):
        #     if get(track.preMirror) == true and preMirrorSplit == false:
        #       if idx == 0:
        #         preMirrorSplit = true
        #       else:
        #         hr()
        #         preMirrorSplit = true
        #   li(class = "row listen"):
        #     tdiv(id = "listen-details"):
        #       if isSome(track.mirrored):
        #         if get(track.mirrored):
        #           img(src = "/assets/mirrored.svg")
        #         else:
        #           img(src = "/assets/pre-mirror.svg")
        #       tdiv(id = "track-details"):
        #         trackName = track.trackName
        #         artistName = track.artistName
        #         p(title = trackName, id = "track-name"):
        #           text trackName
        #         p(title = artistName, id = "artist-name"):
        #           text artistName
        #       let
        #         date = cstring fromUnix(get(track.listenedAt)).format("HH:mm:ss dd/MM/yy")
        #         time = fromUnix(get(track.listenedAt)).format("HH:mm")
        #       span(title = date):
        #         text time

proc mainSection*(user: User, service: Service): Vnode =
  var username, userUrl: cstring

  if user.isNil:
    echo "oh no!"
  case service:
  of Service.listenBrainzService:
    username = user.services[Service.listenBrainzService].username
    userUrl = cstring(lb.userBaseUrl & $username)
  of Service.lastFmService:
    username = user.services[Service.lastFmService].username
    # userUrl = lfm.userBaseUrl & username

  result = buildHtml:
    tdiv:
      tdiv(id = "mirror"):
        p:
          text "You are mirroring "
          a(href = userUrl):
            text $username & "!"
      renderListens(user.playingNow, user.listenHistory)
