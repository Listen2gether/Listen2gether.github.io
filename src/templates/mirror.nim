import std/[options, times]
import pkg/prologue
import pkg/karax/[karaxdsl, vdom]
import share, ../types


proc mainSection(service: Service, user: User): Vnode =
  var
    username, userUrl: string
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
              img(src = "/src/templates/assets/nowplaying.svg")
              tdiv(id = "track-details"):
                p(id = "track-name"):
                  text get(user.playingNow).trackName
                p(id = "artist-name"):
                  text get(user.playingNow).artistName
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
                  img(src = "/src/templates/assets/mirrored.svg")
                else:
                  img(src = "/src/templates/assets/pre-mirror.svg")
              tdiv(id = "track-details"):
                p(id = "track-name"):
                  text track.trackName
                p(id = "artist-name"):
                  text track.artistName
              span(title = fromUnix(get(track.listenedAt)).format("dd/MM/yy")):
                text fromUnix(get(track.listenedAt)).format("HH:mm")

proc mirrorPage*(ctx: Context, service: Service, user: User): string =
  let
    head = head()
    header = headerSection()
    main = mainSection(service, user)
    footer = footerSection()
    vnode = buildHtml(html):
      head
      body:
        tdiv(class = "grid"):
          header
          main
          footer
  result = $vnode