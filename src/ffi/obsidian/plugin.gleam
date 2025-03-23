import ffi/obsidian/file_manager.{type FileManager}
import ffi/obsidian/html_element.{type Event, type HTMLElement}
import ffi/obsidian/markdown_post_processor_context.{
  type MarkdownPostProcessorContext,
}
import ffi/obsidian/vault.{type Vault}
import ffi/obsidian/view.{type View}
import ffi/obsidian/workspace.{type Workspace}
import gleam/dynamic.{type Dynamic}

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

@external(javascript, "src/ffi/obsidian/plugin.ts", "register_view")
pub fn register_view(
  plugin: Plugin,
  view_type: String,
  get_display_text: fn(View) -> String,
  on_open: fn(View) -> Nil,
  on_close: fn(View) -> Nil,
) -> Nil

@external(javascript, "src/ffi/obsidian/plugin.ts", "add_ribbon_button")
pub fn add_ribbon_button(
  plugin: Plugin,
  icon: String,
  title: String,
  callback: fn() -> Nil,
) -> Nil

@external(javascript, "src/ffi/obsidian/plugin.ts", "get_vault")
pub fn get_vault(plugin: Plugin) -> Vault

@external(javascript, "src/ffi/obsidian/plugin.ts", "get_workspace")
pub fn get_workspace(plugin: Plugin) -> Workspace

@external(javascript, "src/ffi/obsidian/plugin.ts", "get_file_manager")
pub fn get_file_manager(plugin: Plugin) -> FileManager

@external(javascript, "src/ffi/obsidian/plugin.ts", "save_data")
pub fn save_data(plugin: Plugin, data: any) -> void

@external(javascript, "src/ffi/obsidian/plugin.ts", "load_data")
pub fn load_data(plugin: Plugin, callback: fn(Dynamic) -> Nil) -> Nil
