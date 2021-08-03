import karax / [karax, karaxdsl, vdom, kdom]
import tools

proc onServiceToggleClick(ev: Event; n: VNode) =
 if getElementById("service_switch").checked:
  getElementById("token").style.display = "none"

proc onUsernameEnter(ev: Event; n: VNode) =
  if not getElementById("service_switch").checked:
    getElementById("token").style.display = "flex"

proc makeMain(): Vnode =
  result = buildHtml(main()):
    tdiv(id = "username", class = "textbox"):
      input(`type` = "text", class = "textinput", id = "username_input", placeholder = "Enter their Username", onkeyupenter = onUsernameEnter)
      label(class = "switch"):
        input(`type` = "checkbox", id = "service_switch", oninput = onServiceToggleClick)
        span(class = "slider")
    tdiv(id = "token", class = "textbox"):
      input(`type` = "text", class = "textinput", id = "token_input", placeholder = "Enter your ListenBrainz token")

proc createDom(): VNode =
  result = buildHtml(tdiv(class = "grid")):
    makeHeader()
    makeMain()
    makeFooter()

setRenderer createDom
