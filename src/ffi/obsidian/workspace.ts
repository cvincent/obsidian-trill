import { TFile, Workspace } from "obsidian";
import { Result, Ok, Error } from "build/dev/javascript/prelude.mjs"

export function get_active_file(workspace: Workspace): Result<TFile, null> {
  let file = workspace.getActiveFile()
  if (file) return new Ok(file)
  else return new Error(null)
}
