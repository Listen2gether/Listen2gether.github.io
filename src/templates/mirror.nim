import karax / [karax, karaxdsl, vdom]
import tools

proc makeMain(): Vnode =
  result = buildHtml(main()):
    tdiv(class = "mirror-grid"):
      tdiv(id = "chat-container"):
        p:
          text "Chat functionality is not ready yet!"
      tdiv(id = "right-panel"):
        p:
          text "You are mirroring!"

proc createDom(): VNode =
  result = buildHtml(tdiv(class = "grid")):
    makeHeader()
    makeMain()
    makeFooter()

setRenderer createDom
