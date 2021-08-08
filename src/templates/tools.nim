import karax / [karaxdsl, vdom]

proc makeHeader*(): Vnode =
  result = buildHtml(header()):
    a(class = "header", href = "/"):
      text "Listen"
      span:
        text "2"
      text "gether"

proc makeFooter*(): Vnode =
  result = buildHtml(footer()):
    a(href = "https://www.gnu.org/licenses/agpl-3.0.html"):
      img(src = "src/templates/assets/agpl.svg", id = "agpl", class = "icon", alt = "GNU AGPL icon")
    a(href = "https://github.com/Listen2gether/website"):
      img(src = "src/templates/assets/github-logo.svg", class = "icon", alt = "GitHub Repository")
