include karax / prelude
import karax / kdom

proc onServiceToggleClick(ev: kdom.Event; n: VNode) =
 if getElementById("service_switch").checked:
  getElementById("token").style.display = "none"

proc onUsernameEnter(ev: kdom.Event; n: VNode) =
  if not getElementById("service_switch").checked:
    getElementById("token").style.display = "flex"

proc makeHeader(): Vnode =
  result = buildHtml(header()):
    a(class = "header", href = "home.html"):
      text "Listen"
      span:
        text "2"
      text "gether"

proc makeMain(): Vnode =
  result = buildHtml(main()):
    tdiv(id = "username"):
      input(`type` = "text", class = "textbox", id = "username_input", placeholder = "Enter their Username", onkeyupenter = onUsernameEnter)
      label(class = "switch"):
        input(`type` = "checkbox", id = "service_switch", oninput = onServiceToggleClick)
        span(class = "slider")
    tdiv(id = "token"):
      input(`type` = "text", class = "textbox", id = "token_input", placeholder = "Enter your ListenBrainz token")

proc makeFooter(): Vnode =
  result = buildHtml(footer()):
    a(href = "https://www.gnu.org/licenses/agpl-3.0.html"):
      img(src = "src/templates/assets/agpl.svg", class = "icon", alt = "GNU AGPL icon")

proc createDom(): VNode =
  result = buildHtml(tdiv(class = "grid")):
    makeHeader()
    makeMain()
    makeFooter()

setRenderer createDom
