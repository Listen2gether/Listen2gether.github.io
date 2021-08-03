import karax / [karax, karaxdsl, vdom]
import tools

proc makeMain(): Vnode =
  result = buildHtml(main()):
    tdiv(class = "mirror-grid")

proc createDom(): VNode =
  result = buildHtml(tdiv(class = "grid")):
    makeHeader()
    makeMain()
    makeFooter()

setRenderer createDom
