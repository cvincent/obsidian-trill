import gleam/dynamic.{type Dynamic}

pub type Menu

@external(javascript, "src/ffi/obsidian/menu.ts", "new_menu")
pub fn new_menu() -> Menu

@external(javascript, "src/ffi/obsidian/menu.ts", "add_item")
pub fn add_item(
  menu: Menu,
  icon: String,
  text: String,
  callback: fn() -> Nil,
) -> Menu

@external(javascript, "src/ffi/obsidian/menu.ts", "show_at_mouse_event")
pub fn show_at_mouse_event(menu: Menu, ev: Dynamic) -> Menu

@external(javascript, "src/ffi/obsidian/menu.ts", "show_at_position")
pub fn show_at_position(menu: Menu, x: Int, y: Int) -> Menu
