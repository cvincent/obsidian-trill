import ffi/obsidian/html_element.{type HTMLElement}

pub type View

@external(javascript, "src/ffi/obsidian/view.ts", "container_el")
pub fn container_el(view: View) -> HTMLElement

@external(javascript, "src/ffi/obsidian/view.ts", "container_el_content")
pub fn container_el_content(view: View) -> HTMLElement
