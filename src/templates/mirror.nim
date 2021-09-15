import std/[times, jsffi, strutils, options]
import karax/[karax, karaxdsl, vdom, kdom, localstorage]
import listenbrainz, jsony
import ../sources/[lb, utils]
# , lfm]
import share
import ../types


proc getPathParams(): (string, string) = 
  let
    pathSeq = split($window.location.pathname, '/')
    serviceString = pathSeq[2]
    username = pathSeq[3]
  result = (serviceString, username)


proc getListenHistory(): (seq[Track], string, string) = 
  let
    pathParams = getPathParams()
    service = pathParams[0]
    username = pathParams[1]
    userId = service & username
    listenHistory = fromJson($getItem(userId), seq[Track])
  var userUrl: string
  # case service:
  #   of "listenbrainz":
  #     # userUrl = user.services[listenBrainzService].baseUrl & username
  #   of "lastfm":
  #     user.services[lastFmService].username = username
  #     # userUrl = user.services[lastFmService].baseUrl & username
  result = (listenHistory, username, userUrl)

proc mainSection(): Vnode =
  let
    userTuple = getListenHistory()
    listenHistory = userTuple[0]
    username = userTuple[1]
    userUrl = userTuple[2]
  result = buildHtml(main()):
    verbatim("<div id = 'mirror'><p>You are mirroring <a href='" & userUrl & "'>" & username & "</a>!</p></div>")
    tdiv(class = "listens"):
      ul:
      #   if isSome(user.playingNow):
      #     li(class = "listen"):
      #       img(src = "/src/templates/assets/listening.svg")
      #       tdiv(id = "listen-details"):
      #         tdiv(id = "track-details"):
      #           p(id = "track-name"):
      #             text get(user.playingNow).trackName
      #           p(id = "artist-name"):
      #             text get(user.playingNow).artistName
      #         span:
      #           text "Playing now"
        for track in listenHistory:
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
