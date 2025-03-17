import ffi/obsidian/html_element.{type Event, type HTMLElement}
import ffi/obsidian/markdown_post_processor_context.{
  type MarkdownPostProcessorContext,
}
import ffi/obsidian/vault.{type Vault}
import ffi/obsidian/workspace.{type Workspace}

pub type Plugin

@external(javascript, "src/ffi/obsidian/plugin.ts", "register_markdown_post_processor")
pub fn register_markdown_post_processor(
  plugin: Plugin,
  processor: fn(HTMLElement, MarkdownPostProcessorContext) -> Nil,
) -> Nil

@external(javascript, "src/ffi/obsidian/plugin.ts", "register_dom_event")
pub fn register_dom_event(
  plugin: Plugin,
  ev_type: String,
  callback: fn(HTMLElement, Event) -> Nil,
) -> Nil

@external(javascript, "src/ffi/obsidian/plugin.ts", "get_vault")
pub fn get_vault(plugin: Plugin) -> Vault

@external(javascript, "src/ffi/obsidian/plugin.ts", "get_workspace")
pub fn get_workspace(plugin: Plugin) -> Workspace
