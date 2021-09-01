import karax/[karaxdsl, vdom]
import prologue
import share
import ../types

proc mainSection(service: Service, user: User): Vnode =
  var username: string
  case service:
    of listenBrainzService:
      username = user.services[listenBrainzService].username
    of lastFmService:
      username = user.services[lastFmService].username
  result = buildHtml(main()):
    verbatim("<div id = 'mirror'><p>You are mirroring <a href='test'>" & username & "</a>!</p></div>")
    tdiv(class = "listens"):
      ul:
        if isSome(user.playingNow):
          li(class = "listen"):
            img(src = "/src/templates/assets/listening.svg")
            tdiv(id = "listen-details"):
              tdiv(id = "track-details"):
                p(id = "track-name"):
                  text get(user.playingNow).trackName
                p(id = "artist-name"):
                  text get(user.playingNow).artistName
              span:
                text "Playing Now"
        for track in user.listenHistory:
          li(class = "listen"):
            img(src = "/src/templates/assets/listened.svg")
            tdiv(id = "listen-details"):
              tdiv(id = "track-details"):
                p(id = "track-name"):
                  text track.trackName
                p(id = "artist-name"):
                  text track.artistName
              span:
                text $get(track.listenedAt)

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