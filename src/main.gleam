import counter
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

pub fn main(plugin: Plugin) {
  plugin.register_view(
    plugin,
    "trill",
    fn(_) { "Trill" },
    fn(view) {
      console.log("onOpen")
      let container = view.container_el_content(view)
      html_element.create_el_with_class(container, "div", "trill-container")
      let assert Ok(_) = lustre.start(counter.app(), ".trill-container", Nil)
      Nil
    },
    fn(_) { console.log("onClose") },
  )

  plugin.add_ribbon_button(plugin, "dice", "Hello world", fn() {
    let workspace = plugin.get_workspace(plugin)
    let leaves = workspace.get_leaves_of_type(workspace, "trill")
    console.log(leaves)

    let leaf = case list.length(leaves) > 0 {
      True -> {
        let assert Ok(leaf) = list.first(leaves)
        console.log(leaf)
        leaf
      }
      False -> {
        let leaf = workspace.get_leaf(workspace, "tab")
        console.log(leaf)
        workspace.leaf_set_view_state(leaf, "trill", True)
        leaf
      }
    }

    workspace.reveal_leaf(workspace, leaf)

    Nil
  })
}
