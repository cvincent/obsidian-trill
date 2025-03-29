import ffi/obsidian/app.{type App}
import ffi/obsidian/file_manager.{type FileManager}
import ffi/obsidian/plugin.{type Plugin}
import ffi/obsidian/vault.{type Vault}
import ffi/obsidian/workspace.{type Workspace}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import gleam/result

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

pub fn set_front_matter(
  ctx: ObsidianContext,
  path: String,
  prop: String,
  val: Option(String),
) {
  let _ = {
    use file <- result.try(vault.get_file_by_path(ctx.vault, path))

    ctx.file_manager
    |> file_manager.process_front_matter(file, fn(_yaml) { [#(prop, val)] })
    |> Ok()
  }
  Nil
}

@external(javascript, "src/obsidian_context.ts", "add_tag")
pub fn add_tag(ctx: ObsidianContext, path: String, tag: String) -> Nil
