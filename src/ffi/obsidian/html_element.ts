import { Result, Ok, Error, List } from "build/dev/javascript/prelude.mjs"
import { Event } from "build/dev/javascript/obsidian_plugin/ffi/obsidian/html_element.mjs"

export function create_el(
  el: HTMLElement,
  tag: keyof HTMLElementTagNameMap,
  info: DomElementInfo
): HTMLElement {
  return el.createEl(tag, info)
}

export function find(
  el: HTMLElement,
  selector: string
): Result<HTMLElement, null> {
  let found = el.find(selector)
  if (found) return new Ok(found)
  else return new Error(null)
}

export function find_all(el: HTMLElement, selector: string): List<HTMLElement> {
  return List.fromArray(el.findAll(selector))
}

export function on(
  el: HTMLElement,
  selector: string,
  type: keyof HTMLElementEventMap,
  listener: (el: HTMLElement, ev: Event) => any
): void {
  el.on(type, selector, function(ev: MouseEvent) {
    listener(this, new Event(ev, ev.target, ev.which))
  })
}

export function on_click_event(
  el: HTMLElement,
  listener: (el: HTMLElement, ev: Event) => any
): void {
  el.onClickEvent(function(ev) {
    listener(this, new Event(ev, ev.target, ev.which))
  })
}

export function class_list(el: HTMLElement): DOMTokenList {
  return el.classList
}

export function dataset(el: any): List<Array<string>> {
  return el.dataset.keys().map((k: any) => [k, el.dataset[k]])
}

export function match_parent(el: HTMLElement, selector: string): Result<HTMLElement, null> {
  let found = el.matchParent(selector)
  if (found) return new Ok(found)
  else return new Error(null)
}

export function set_attr(el: HTMLElement, key: string, val: string): void {
  el.setAttr(key, val)
}

export function get_attr(el: HTMLElement, key: string): Result<string, null> {
  let val = el.getAttr(key)
  if (val) return new Ok(val)
  else return new Error(null)
}

export function get_checked(el: any): boolean {
  return el.defaultChecked
}
