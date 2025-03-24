import ffi/obsidian/app.{type App}
import plinth/browser/element.{type Element}

pub type Modal

@external(javascript, "src/ffi/obsidian/modal.ts", "open")
pub fn open(
  app: App,
  on_open on_open: fn(Modal, Element) -> Nil,
  on_close on_close: fn(Modal, Element) -> Nil,
) -> Modal

@external(javascript, "src/ffi/obsidian/modal.ts", "close")
pub fn close(modal: Modal) -> Nil
