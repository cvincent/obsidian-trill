import ffi/console
import ffi/event
import ffi/obsidian/file.{type File}
import ffi/obsidian/html_element.{type Event, type HTMLElement}
import ffi/obsidian/markdown_post_processor_context.{type MarkdownSectionInfo}
import ffi/obsidian/menu
import ffi/obsidian/plugin.{type Plugin}
import ffi/obsidian/vault
import ffi/obsidian/view.{type View}
import ffi/obsidian/workspace
import gleam/dict
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre
import trill

pub fn main(plugin: Plugin) {
  plugin.register_view(
    plugin,
    trill.view_name,
    fn(_) { "Trill" },
    fn(view) {
      let container = view.container_el_content(view)
      html_element.create_el_with_class(container, "div", "trill-container")
      let assert Ok(_) = lustre.start(trill.app(), ".trill-container", plugin)
      Nil
    },
    fn(_) { Nil },
  )

  plugin.add_ribbon_button(plugin, "dice", "Hello world", fn() {
    let workspace = plugin.get_workspace(plugin)
    let leaves = workspace.get_leaves_of_type(workspace, trill.view_name)

    let leaf = case list.length(leaves) > 0 {
      True -> {
        let assert Ok(leaf) = list.first(leaves)
        leaf
      }
      False -> {
        // "window" would be cool too but for some reason the Lustre app doesn't
        // render there...
        let leaf = workspace.get_leaf(workspace, "tab")
        workspace.leaf_set_view_state(leaf, trill.view_name, True)
        leaf
      }
    }

    workspace.reveal_leaf(workspace, leaf)

    Nil
  })
}
