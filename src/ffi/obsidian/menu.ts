import { Menu } from "obsidian";

export function new_menu(): Menu {
  return new Menu()
}

export function add_item(menu: Menu, text: string, callback: () => void): void {
  menu.addItem((item) => {
    item
      .setTitle(text)
      .onClick(callback)
  })
}

export function show_at_mouse_event(menu: Menu, ev: MouseEvent): void {
  menu.showAtMouseEvent(ev)
}

export function show_at_position(menu: Menu, x: number, y: number): void {
  menu.showAtPosition({ x, y })
}
