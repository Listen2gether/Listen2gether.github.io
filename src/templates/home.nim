import
  pkg/karax/[karax, karaxdsl, vdom, kdom],
  share

proc onServiceToggleClick(ev: Event; n: VNode) =
  ## Switches service toggle on click
  if getElementById("service_switch").checked:
    getElementById("token").style.display = "none"
  else:
    getElementById("token").style.display = "flex"

proc onTokenEnter(ev: Event; n: VNode) =
  ## Routes to mirror page on token enter
  var service: string = ""
  let
    username = $getElementById("username_input").value
    token = $getElementById("token_input").value
    serviceSwitch = getElementById("service_switch").checked
  if serviceSwitch:
    service = "lastfm"
    window.location.href = cstring("/mirror/" & service & "/" & username)
  else:
    service = "listenbrainz"
    # let lb = AsyncListenBrainz()
    # if token != "":
    #   let validToken = await lb.validateLbToken(token)
    #   if validToken:
    window.location.href = cstring("/mirror/" & service & "/" & username & "?token=" & token)

proc mainSection(): Vnode =
  ## Generates main section for Home page.
  result = buildHtml(main()):
    tdiv(class = "container"):
      tdiv(id = "title-container", class = "col"):
        p(id = "title"):
          a(class = "header", href = "/"):
            text "Listen"
            span: text "2"
            text "gether"
          text " is a website for listen parties."
        p(id = "subtitle"):
          text "Whether you're physically in the same room or not."
      tdiv(id = "login-container", class = "col"):
        p(id = "body"):
          text "Enter a username and select a service to start mirroring another user's listens."
        tdiv(id = "username", class = "textbox"):
          input(`type` = "text", class = "textinput", id = "username_input", placeholder = "Enter username")
          label(class = "switch"):
            input(`type` = "checkbox", id = "service_switch", oninput = onServiceToggleClick)
            span(class = "slider")
        tdiv(id = "token", class = "textbox"):
          input(`type` = "text", class = "textinput", id = "token_input", placeholder = "Enter your ListenBrainz token", onkeyupenter = onTokenEnter)
    tdiv(class = "container"):
      tdiv(id = "description-container", class = "col"):
        p(id = "body"):
          text "Virtual listen parties are powered by ListenBrainz and a Matrix chatroom."
      tdiv(id = "logo-container", class = "col"):
        a(href = "https://listenbrainz.org/",
          img(
            src = "/public/assets/listenbrainz-logo.svg",
            id = "listenbrainz-logo",
            class = "logo",
            alt = "ListenBrainz.org logo"
          )
        )
        a(href = "https://matrix.org/",
          img(
            src = "/public/assets/matrix-logo.svg",
            id = "matrix-logo",
            class = "logo",
            alt = "Matrix.org logo",
          )
        )

proc createDom(): VNode =
  result = buildHtml(tdiv()):
    headerSection()
    mainSection()
    footerSection()

setRenderer createDom
