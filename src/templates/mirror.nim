import karax / [karax, karaxdsl, vdom]
import tools

proc makeMain(): Vnode =
  result = buildHtml(main()):
    verbatim("<div id = 'mirror'><p>You are mirroring <a href='test'>X</a>!</p></div>")
    tdiv(class = "listens"):
      ul:
        li(class = "listen"):
          img(src = "src/templates/assets/listening.svg")
          tdiv(id = "listen-details"):
            tdiv(id = "track-details"):
              p(id = "track-name"): text "Ai No Shizuku"
              p(id = "artist-name"): text "Nobue Kawana"
            span: text "24 Jul, 3:58 pm"
        li(class = "listen"):
          img(src = "src/templates/assets/listened.svg")
          tdiv(id = "listen-details"):
            tdiv(id = "track-details"):
              p(id = "track-name"): text "Ai No Shizuku"
              p(id = "artist-name"): text "Nobue Kawana"
            span: text "24 Jul, 3:58 pm"
        li(class = "listen"):
          img(src = "src/templates/assets/listened.svg")
          tdiv(id = "listen-details"):
            tdiv(id = "track-details"):
              p(id = "track-name"): text "Ai No Shizuku"
              p(id = "artist-name"): text "Nobue Kawana"
            span: text "24 Jul, 3:58 pm"
        li(class = "listen"):
          img(src = "src/templates/assets/listened.svg")
          tdiv(id = "listen-details"):
            tdiv(id = "track-details"):
              p(id = "track-name"): text "Ai No Shizuku"
              p(id = "artist-name"): text "Nobue Kawana"
            span: text "24 Jul, 3:58 pm"
        li(class = "listen"):
          img(src = "src/templates/assets/pre-mirror-listen.svg")
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
