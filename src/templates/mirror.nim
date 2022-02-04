import
  std/[options, times],
  pkg/prologue,
  pkg/karax/[karaxdsl, vdom],
  share,
  ../types


proc mainSection(service: Service, user: User): Vnode =
  ## Generates main section for Mirror page.
  var
    username, userUrl, trackName, artistName: string
    preMirrorSplit: bool = false
    maxListens: int = 7

  case service:
    of listenBrainzService:
      username = user.services[listenBrainzService].username
      userUrl = user.services[listenBrainzService].baseUrl & username
    of lastFmService:
      username = user.services[lastFmService].username
      userUrl = user.services[lastFmService].baseUrl & username

  result = buildHtml(main()):
    verbatim("<div id = 'mirror'><p>You are mirroring <a href='" & userUrl & "'>" & username & "</a>!</p></div>")
    tdiv(class = "listens"):
      ul:
        if isSome(user.playingNow):
          li(class = "listen"):
            tdiv(id = "listen-details"):
              img(src = "/public/assets/nowplaying.svg")
              tdiv(id = "track-details"):
                trackName = get(user.playingNow).trackName
                artistName = get(user.playingNow).artistName
                p(title = trackName, id = "track-name"):
                  text trackName
                p(title = artistName, id = "artist-name"):
                  text artistName
              span:
                text "Playing now"
          maxListens = 6
        for idx, track in user.listenHistory[0..maxListens]:
          if isSome(track.preMirror):
            if get(track.preMirror) == true and preMirrorSplit == false:
              if idx == 0:
                preMirrorSplit = true
              else:
                hr()
                preMirrorSplit = true
          li(class = "listen"):
            tdiv(id = "listen-details"):
              if isSome(track.mirrored):
                if get(track.mirrored):
                  img(src = "/public/assets/mirrored.svg")
                else:
                  img(src = "/public/assets/pre-mirror.svg")
              tdiv(id = "track-details"):
                trackName = track.trackName
                artistName = track.artistName
                p(title = trackName, id = "track-name"):
                  text trackName
                p(title = artistName, id = "artist-name"):
                  text artistName
              span(title = fromUnix(get(track.listenedAt)).format("HH:mm:ss dd/MM/yy")):
                text fromUnix(get(track.listenedAt)).format("HH:mm")

proc mirrorPage*(ctx: Context, service: Service, user: User): string =
  ## Generates Mirror page.
  let
    head = head()
    header = headerSection()
    main = mainSection(service, user)
    footer = footerSection()
    vnode = buildHtml(html):
      head
      body:
        tdiv(id = "ROOT"):
          header
          main
          footer
  result = $vnode