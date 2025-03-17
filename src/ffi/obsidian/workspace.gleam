import ffi/obsidian/file.{type File}

pub type Workspace

@external(javascript, "src/ffi/obsidian/workspace.ts", "get_active_file")
pub fn get_active_file(workspace: Workspace) -> Result(File, Nil)
