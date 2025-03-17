import plinth/browser/dom_token_list.{type DomTokenList}

pub type HTMLElement

pub type JSEvent

pub type Event {
  Event(js_event: JSEvent, target: HTMLElement, which: Int)
}

@external(javascript, "src/ffi/obsidian/html_element.ts", "create_el")
pub fn create_el(el: HTMLElement, tag: String, info: info) -> HTMLElement

@external(javascript, "src/ffi/obsidian/html_element.ts", "find")
pub fn find(el: HTMLElement, selector: String) -> Result(HTMLElement, Nil)

@external(javascript, "src/ffi/obsidian/html_element.ts", "find_all")
pub fn find_all(el: HTMLElement, selector: String) -> List(HTMLElement)

@external(javascript, "src/ffi/obsidian/html_element.ts", "on")
pub fn on(
  el: HTMLElement,
  selector: String,
  ev_type: String,
  listener: fn(HTMLElement, event) -> Nil,
) -> Nil

@external(javascript, "src/ffi/obsidian/html_element.ts", "on_click_event")
pub fn on_click_event(
  el: HTMLElement,
  listener: fn(HTMLElement, Event) -> Nil,
) -> Nil

@external(javascript, "src/ffi/obsidian/html_element.ts", "class_list")
pub fn class_list(el: HTMLElement) -> DomTokenList

@external(javascript, "src/ffi/obsidian/html_element.ts", "dataset")
pub fn dataset(el: HTMLElement) -> List(#(String, String))

@external(javascript, "src/ffi/obsidian/html_element.ts", "match_parent")
pub fn match_parent(
  el: HTMLElement,
  selector: String,
) -> Result(HTMLElement, Nil)

@external(javascript, "src/ffi/obsidian/html_element.ts", "set_attr")
pub fn set_attr(el: HTMLElement, key: String, val: String) -> Nil

@external(javascript, "src/ffi/obsidian/html_element.ts", "get_attr")
pub fn get_attr(el: HTMLElement, key: String) -> Result(String, Nil)

@external(javascript, "src/ffi/obsidian/html_element.ts", "get_checked")
pub fn get_checked(el: HTMLElement) -> Bool
