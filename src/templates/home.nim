import karax/[karax, karaxdsl, vdom, kdom]
import share

proc onServiceToggleClick(ev: Event; n: VNode) =
 if getElementById("service_switch").checked:
  getElementById("token").style.display = "none"
  

proc onUsernameEnter(ev: Event; n: VNode) =
  # if not getElementById("service_switch").checked:
  #   getElementById("token").style.display = "flex"
  var service: string = ""
  let
    username = $getElementById("username_input").value
    serviceSwitch = getElementById("service_switch").checked
  if serviceSwitch:
    service = "lastfm"
  else:
    service = "listenbrainz"
  window.location.href = cstring("/mirror/" & service & "/" & username)
  

proc mainSection(): Vnode =
  result = buildHtml(main()):
    tdiv(id = "login"):
      tdiv(id = "username", class = "textbox"):
        input(`type` = "text", class = "textinput", id = "username_input", placeholder = "Enter username / room ID", onkeyupenter = onUsernameEnter)
        label(class = "switch"):
          input(`type` = "checkbox", id = "service_switch", oninput = onServiceToggleClick)
          span(class = "slider")
      # tdiv(id = "token", class = "textbox"):
      #   input(`type` = "text", class = "textinput", id = "token_input", placeholder = "Enter your ListenBrainz token")

proc createDom(): VNode =
  result = buildHtml(tdiv(class = "grid")):
    headerSection()
    mainSection()
    footerSection()

setRenderer createDom
