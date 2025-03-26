import ffi/obsidian/file.{type File}
import gleam/javascript/promise.{type Promise}

pub type Vault

@external(javascript, "src/ffi/obsidian/vault.ts", "process")
pub fn process(vault: Vault, file: File, callback: fn(String) -> String) -> Nil

@external(javascript, "src/ffi/obsidian/vault.ts", "get_file_by_path")
pub fn get_file_by_path(vault: Vault, path: String) -> Result(File, Nil)

@external(javascript, "src/ffi/obsidian/vault.ts", "cached_read")
pub fn cached_read(vault: Vault, file: File) -> Promise(String)

@external(javascript, "src/ffi/obsidian/vault.ts", "on")
pub fn on(vault: Vault, event: String, callback: fn(File) -> Nil) -> Nil
