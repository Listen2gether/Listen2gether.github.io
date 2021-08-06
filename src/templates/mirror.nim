import karax / [karax, karaxdsl, vdom]
import tools

proc makeMain(): Vnode =
  result = buildHtml(main()):
    tdiv(class = "listens"):
      ul:
        li:
          img(src = "src/templates/assets/listening.gif", id = "scrobble", class = "icon")
          tdiv(id = "listen-details"):
            tdiv(id = "track-details"):
              p(id = "track-name"): text "Ai No Shizuku"
              p(id = "artist-name"): text "Nobue Kawana"
            span: text "24 Jul, 3:58 pm"
        li:
          img(src = "src/templates/assets/listened.svg", id = "listened", class = "icon")
          tdiv(id = "listen-details"):
            tdiv(id = "track-details"):
              p(id = "track-name"): text "Ai No Shizuku"
              p(id = "artist-name"): text "Nobue Kawana"
            span: text "24 Jul, 3:58 pm"
        li:
          img(src = "src/templates/assets/listened.svg", id = "listened", class = "icon")
          tdiv(id = "listen-details"):
            tdiv(id = "track-details"):
              p(id = "track-name"): text "Ai No Shizuku"
              p(id = "artist-name"): text "Nobue Kawana"
            span: text "24 Jul, 3:58 pm"
        li:
          img(src = "src/templates/assets/listened.svg", id = "listened", class = "icon")
          tdiv(id = "listen-details"):
            tdiv(id = "track-details"):
              p(id = "track-name"): text "Ai No Shizuku"
              p(id = "artist-name"): text "Nobue Kawana"
            span: text "24 Jul, 3:58 pm"

proc createDom(): VNode =
  result = buildHtml(tdiv(class = "grid")):
    makeHeader()
    makeMain()
    makeFooter()

setRenderer createDom
