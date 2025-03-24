import ffi/obsidian/app.{type App}
import ffi/obsidian/file_manager.{type FileManager}
import ffi/obsidian/plugin.{type Plugin}
import ffi/obsidian/vault.{type Vault}
import ffi/obsidian/workspace.{type Workspace}
import gleam/dynamic.{type Dynamic}

pub type ObsidianContext {
  ObsidianContext(
    app: App,
    file_manager: FileManager,
    plugin: Plugin,
    saved_data: Dynamic,
    vault: Vault,
    workspace: Workspace,
  )
}
