import { Plugin, MarkdownPostProcessor, Vault, Workspace } from "obsidian";
import { Event } from "build/dev/javascript/obsidian_plugin/ffi/obsidian/html_element.mjs"

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

export function get_vault(plugin: Plugin): Vault {
  return plugin.app.vault
}

export function get_workspace(plugin: Plugin): Workspace {
  return plugin.app.workspace
}
