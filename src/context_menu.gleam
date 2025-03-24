import ffi/obsidian/menu
import gleam/dynamic.{type Dynamic}
import gleam/list
import lustre/effect

pub fn show(
  ev: Dynamic,
  items: List(#(String, String, fn(fn(a) -> Nil) -> Nil)),
) {
  effect.from(fn(dispatch) {
    let menu = menu.new_menu()
    list.each(items, fn(item) {
      let #(name, icon, func) = item
      menu.add_item(menu, icon, name, fn() { func(dispatch) })
    })
    menu.show_at_mouse_event(menu, ev)
    Nil
  })
}
