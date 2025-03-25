import ffi/console
import ffi/obsidian/app.{type App}
import gleam/json
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event
import plinth/browser/element.{type Element as PElement} as pelement

pub type Modal

@external(javascript, "src/ffi/obsidian/modal.ts", "create")
pub fn create(
  app: App,
  on_open on_open: fn(Modal, PElement) -> Nil,
  on_close on_close: fn(Modal, PElement) -> Nil,
) -> Modal

pub fn with_element(app: App, el: Element(a)) -> Modal {
  let inner_html = element.to_string(el)

  create(
    app,
    on_open: fn(_modal, content_el) {
      pelement.set_inner_html(content_el, inner_html)
      Nil
    },
    on_close: fn(_modal, _content_element) { Nil },
  )
}

@external(javascript, "src/ffi/obsidian/modal.ts", "open")
pub fn open(modal: Modal) -> Nil

@external(javascript, "src/ffi/obsidian/modal.ts", "close")
pub fn close(modal: Modal) -> Nil
