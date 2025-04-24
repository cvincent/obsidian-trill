import ffi/obsidian/menu
import gleam/dynamic.{type Dynamic}
import gleam/list

pub fn show(ev: Dynamic, items: List(#(String, String, fn() -> Nil))) {
  let menu = menu.new_menu()
  list.each(items, fn(item) {
    let #(name, icon, func) = item
    menu.add_item(menu, icon, name, func)
  })
  menu.show_at_mouse_event(menu, ev)
}
