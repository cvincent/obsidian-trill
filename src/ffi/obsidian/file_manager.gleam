import ffi/obsidian/file.{type File}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}

pub type FileManager

@external(javascript, "src/ffi/obsidian/file_manager.ts", "process_front_matter")
pub fn process_front_matter(
  fm: FileManager,
  file: File,
  callback: fn(Dynamic) -> List(#(String, Option(String))),
) -> Nil
