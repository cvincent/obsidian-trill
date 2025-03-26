import ffi/obsidian/file.{type File}
import gleam/dynamic.{type Dynamic}

pub type Workspace

pub type WorkspaceLeaf

@external(javascript, "src/ffi/obsidian/workspace.ts", "get_active_file")
pub fn get_active_file(workspace: Workspace) -> Result(File, Nil)

@external(javascript, "src/ffi/obsidian/workspace.ts", "get_leaves_of_type")
pub fn get_leaves_of_type(
  workspace: Workspace,
  view_type: String,
) -> List(WorkspaceLeaf)

@external(javascript, "src/ffi/obsidian/workspace.ts", "get_leaf")
pub fn get_leaf(workspace: Workspace, pane_type: String) -> WorkspaceLeaf

@external(javascript, "src/ffi/obsidian/workspace.ts", "leaf_set_view_state")
pub fn leaf_set_view_state(
  leaf: WorkspaceLeaf,
  view_type: String,
  active: Bool,
) -> Nil

@external(javascript, "src/ffi/obsidian/workspace.ts", "reveal_leaf")
pub fn reveal_leaf(workspace: Workspace, leaf: WorkspaceLeaf) -> Nil

@external(javascript, "src/ffi/obsidian/workspace.ts", "open_link_text")
pub fn open_link_text(
  workspace: Workspace,
  source_path: String,
  pane_type: String,
) -> Nil

@external(javascript, "src/ffi/obsidian/workspace.ts", "trigger_hover_link")
pub fn trigger_hover_link(
  workspace: Workspace,
  event: Dynamic,
  view_name: String,
  source_path: String,
) -> Nil

@external(javascript, "src/ffi/obsidian/workspace.ts", "on_layout_ready")
pub fn on_layout_ready(workspace: Workspace, callback: fn() -> Nil) -> Nil
