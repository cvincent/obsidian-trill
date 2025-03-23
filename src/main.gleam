import components
import ffi/obsidian/html_element
import ffi/obsidian/plugin.{type Plugin}
import ffi/obsidian/view
import ffi/obsidian/workspace
import gleam/list
import lustre
import trill

pub fn main(plugin: Plugin) {
  components.setup()

  use data <- plugin.load_data(plugin)

  plugin.register_view(
    plugin,
    trill.view_name,
    fn(_) { "Trill" },
    fn(view) {
      let container = view.container_el_content(view)
      html_element.create_el_with_class(
        container,
        "div",
        "trill-container h-full",
      )

      let assert Ok(_) =
        lustre.start(trill.app(), ".trill-container", #(plugin, data))
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
