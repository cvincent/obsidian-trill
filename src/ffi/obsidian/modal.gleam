import ffi/obsidian/app.{type App}
import lustre/element.{type Element}
import plinth/browser/element.{type Element as PElement} as pelement

pub type Modal

@external(javascript, "src/ffi/obsidian/modal.ts", "open")
pub fn open(
  app: App,
  on_open on_open: fn(Modal, PElement) -> Nil,
  on_close on_close: fn(Modal, PElement) -> Nil,
) -> Modal

@external(javascript, "src/ffi/obsidian/modal.ts", "close")
pub fn close(modal: Modal) -> Nil

pub fn with_element(app: App, el: Element(a)) {
  let inner_html = element.to_string(el)

  open(
    app,
    on_open: fn(_modal, content_el) {
      pelement.set_inner_html(content_el, inner_html)
      Nil
    },
    on_close: fn(_modal, _content_element) { Nil },
  )
}
