import ffi/obsidian/html_element.{type JSEvent}

pub type Menu

@external(javascript, "src/ffi/obsidian/menu.ts", "new_menu")
pub fn new_menu() -> Menu

@external(javascript, "src/ffi/obsidian/menu.ts", "add_item")
pub fn add_item(menu: Menu, text: String, callback: fn() -> Nil) -> Menu

@external(javascript, "src/ffi/obsidian/menu.ts", "show_at_mouse_event")
pub fn show_at_mouse_event(menu: Menu, ev: JSEvent) -> Menu

@external(javascript, "src/ffi/obsidian/menu.ts", "show_at_position")
pub fn show_at_position(menu: Menu, x: Int, y: Int) -> Menu
