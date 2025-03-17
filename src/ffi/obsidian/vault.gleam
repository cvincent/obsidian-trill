import ffi/obsidian/file.{type File}

pub type Vault

@external(javascript, "src/ffi/obsidian/vault.ts", "process")
pub fn process(vault: Vault, file: File, callback: fn(String) -> String) -> Nil

@external(javascript, "src/ffi/obsidian/vault.ts", "get_file_by_path")
pub fn get_file_by_path(vault: Vault, path: String) -> Result(File, Nil)
