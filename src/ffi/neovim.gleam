import ffi/obsidian/file.{type File}
import ffi/obsidian/vault.{type Vault}
import gleam/dynamic.{type Dynamic}

@external(javascript, "src/ffi/neovim.ts", "open_file")
pub fn open_file(vault: Vault, neovim: Dynamic, file: File) -> Nil
