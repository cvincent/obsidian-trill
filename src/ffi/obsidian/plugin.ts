import { Plugin, MarkdownPostProcessor, Vault, Workspace } from "obsidian";
import { Event } from "build/dev/javascript/obsidian_plugin/ffi/obsidian/html_element.mjs"
import { LustreView } from "./view";

export function register_markdown_post_processor(plugin: Plugin, processor: MarkdownPostProcessor) {
  plugin.registerMarkdownPostProcessor(processor)
}

export function register_dom_event(
  plugin: Plugin,
  ev_type: keyof HTMLElementEventMap,
  callback: (el: HTMLElement, ev: Event) => void
): void {
  plugin.registerDomEvent(document, ev_type, function(ev) {
    callback(this, new Event(ev, ev.target, 0))
  })
}

export function register_view(
  plugin: Plugin,
  view_type: string,
  get_display_text: (view: LustreView) => string,
  on_open: (view: LustreView) => void,
  on_close: (view: LustreView) => void
): void {
  plugin.registerView(view_type, (leaf) => new LustreView(leaf, view_type, get_display_text, on_open, on_close))
}

export function add_ribbon_button(
  plugin: Plugin,
  icon: string,
  title: string,
  callback: () => void
): void {
  plugin.addRibbonIcon(icon, title, callback)
}

export function get_vault(plugin: Plugin): Vault {
  return plugin.app.vault
}

export function get_workspace(plugin: Plugin): Workspace {
  return plugin.app.workspace
}
