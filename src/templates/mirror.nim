import std/[times, strutils, options]
import karax/[karax, karaxdsl, vdom, kdom]
import listenbrainz
import ../sources/[lb]
# , lfm]
import share
import ../types

proc getPathParams(): (Service, string) = 
  var service: Service
  let
    pathSeq = split($window.location.pathname, '/')
    serviceString = pathSeq[2]
    username = pathSeq[3]
  case serviceString:
    of "listenbrainz":
      service = listenBrainzService
    of "lastfm":
      service = lastFmService
  result = (service, username)

proc createUser(): (User, string, string) = 
  let
    pathParams = getPathParams()
    service = pathParams[0]
    username = pathParams[1]
  var
    user: User = newUser()
    userUrl: string
  case service:
    of listenBrainzService:
      user.services[listenBrainzService].username = username
      userUrl = user.services[listenBrainzService].baseUrl & username
      let asyncListenBrainz = newAsyncListenBrainz()
      let update = asyncListenBrainz.updateUser(user)
    of lastFmService:
      user.services[lastFmService].username = username
      userUrl = user.services[lastFmService].baseUrl & username
  result = (user, username, userUrl)

proc mainSection(): Vnode =
  let
    userTup = createUser()
    user = userTup[0]
    username = userTup[1]
    userUrl = userTup[2]
  result = buildHtml(main()):
    verbatim("<div id = 'mirror'><p>You are mirroring <a href='" & userUrl & "'>" & username & "</a>!</p></div>")
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
                text "Playing now"
        for track in user.listenHistory:
          li(class = "listen"):
            img(src = "/src/templates/assets/pre-mirror-listen.svg")
            tdiv(id = "listen-details"):
              tdiv(id = "track-details"):
                p(id = "track-name"):
                  text track.trackName
                p(id = "artist-name"):
                  text track.artistName
              span(title = fromUnix(get(track.listenedAt)).format("dd/MM/yy")):
                text fromUnix(get(track.listenedAt)).format("HH:mm")

proc createDom*(): VNode =
  let
    head = head()
    header = headerSection()
    main = mainSection()
    footer = footerSection()
  result = buildHtml(html):
    head
    body:
      tdiv(class = "grid"):
        header
        main
        footer

setRenderer createDom
