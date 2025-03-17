import ffi/obsidian/file.{type File}

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
