import pkg/karax/[karaxdsl, vdom]


proc head*(): Vnode =
  result = buildHtml(head):
    meta(charset="utf-8", name="viewport", content="width=device-width, initial-scale=1")
    title: text "Listen2gether"
    link(rel="icon", href="/src/templates/assets/favicon_square.svg")
    link(rel="stylesheet", href="/src/templates/style.css")


proc headerSection*(): Vnode =
  result = buildHtml(header):
    a(class = "header", href = "/"):
      text "Listen"
      span: text "2"
      text "gether"


proc footerSection*(): Vnode =
  result = buildHtml(footer):
    a(href = "https://www.gnu.org/licenses/agpl-3.0.html"):
      img(src = "/src/templates/assets/agpl.svg", id = "agpl", class = "icon", alt = "GNU AGPL icon")
    a(href = "https://github.com/Listen2gether/website"):
      img(src = "/src/templates/assets/github-logo.svg", class = "icon", alt = "GitHub Repository")
