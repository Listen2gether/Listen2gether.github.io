import karax / kdom
import tools

proc onServiceToggleClick(ev: kdom.Event; n: VNode) =
 if getElementById("service_switch").checked:
  getElementById("token").style.display = "none"

proc onUsernameEnter(ev: kdom.Event; n: VNode) =
  if not getElementById("service_switch").checked:
    getElementById("token").style.display = "flex"

proc makeMain(): Vnode =
  result = buildHtml(main()):
    tdiv(id = "username"):
      input(`type` = "text", class = "textbox", id = "username_input", placeholder = "Enter their Username", onkeyupenter = onUsernameEnter)
      label(class = "switch"):
        input(`type` = "checkbox", id = "service_switch", oninput = onServiceToggleClick)
        span(class = "slider")
    tdiv(id = "token"):
      input(`type` = "text", class = "textbox", id = "token_input", placeholder = "Enter your ListenBrainz token")

proc createDom(): VNode =
  result = buildHtml(tdiv(class = "grid")):
    makeHeader()
    makeMain()
    makeFooter()

setRenderer createDom