import karax / [karax, karaxdsl, vdom]
import tools

proc makeMain(): Vnode =
  result = buildHtml(main()):
    tdiv(id = "username")

proc createDom(): VNode =
  result = buildHtml(tdiv(class = "grid")):
    makeHeader()
    makeMain()
    makeFooter()

setRenderer createDom
