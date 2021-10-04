import pkg/karax/[karax, karaxdsl, vdom, kdom]
import share

proc onServiceToggleClick(ev: Event; n: VNode) =
  if getElementById("service_switch").checked:
    getElementById("token").style.display = "none"
  else:
    getElementById("token").style.display = "flex"
  

proc onTokenEnter(ev: Event; n: VNode) =
  var service: string = ""
  let
    username = $getElementById("username_input").value
    token = $getElementById("token_input").value
    serviceSwitch = getElementById("service_switch").checked
  if serviceSwitch:
    service = "lastfm"
  else:
    service = "listenbrainz"
  window.location.href = cstring("/mirror/" & service & "/" & username & "?token=" & token)
  

proc mainSection(): Vnode =
  result = buildHtml(main()):
    tdiv(class = "inner-grid"):
      tdiv(id = "grid-1", class = "col"):
        p(id = "title"):
          a(class = "header", href = "/"):
            text "Listen"
            span: text "2"
            text "gether"
          text " is a website for listen parties."
        p(id = "subtitle"):
          text "Whether you're physically in the same room or not."
      tdiv(id = "grid-2", class = "col"):
        img(src = "/src/templates/assets/screenshot.png", id = "demo", alt = "Mirroring page")
      tdiv(id = "grid-3", class = "col"):
        tdiv(id = "username", class = "textbox"):
          input(`type` = "text", class = "textinput", id = "username_input", placeholder = "Enter username / room ID")
          label(class = "switch"):
            input(`type` = "checkbox", id = "service_switch", oninput = onServiceToggleClick)
            span(class = "slider")
        tdiv(id = "token", class = "textbox"):
          input(`type` = "text", class = "textinput", id = "token_input", placeholder = "Enter your ListenBrainz token", onkeyupenter = onTokenEnter)
      tdiv(id = "grid-4", class = "col"):
        p(id = "body"):
          text "Virtual listen parties are powered by Youtube and Spotify, and a Matrix chatroom."
        p(id = "body"):
          text "Enter a username and select a service to start mirroring another user's listens."

proc createDom(): VNode =
  result = buildHtml(tdiv(class = "grid")):
    headerSection()
    mainSection()
    footerSection()

setRenderer createDom
