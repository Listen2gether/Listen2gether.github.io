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
    a(href = "https://www.gnu.org/licenses/agpl-3.0.html", class = "icon"):
      img(src = "src/templates/assets/agpl.svg", id = "agpl", alt = "GNU AGPL icon")
    a(href = "https://github.com/Listen2gether/website", class = "icon"):
      img(src = "src/templates/assets/github-logo.svg", id = "github", alt = "GitHub Repository")
