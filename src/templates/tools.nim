include karax / prelude

proc makeHeader*(): Vnode =
  result = buildHtml(header()):
    a(class = "header", href = "home.html"):
      text "Listen"
      span:
        text "2"
      text "gether"

proc makeFooter*(): Vnode =
  result = buildHtml(footer()):
    a(href = "https://www.gnu.org/licenses/agpl-3.0.html"):
      img(src = "src/templates/assets/agpl.svg", class = "icon", alt = "GNU AGPL icon")
