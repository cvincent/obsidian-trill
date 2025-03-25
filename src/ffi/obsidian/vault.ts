import { TAbstractFile, TFile, Vault } from "obsidian";
import { Result, Ok, Error } from "build/dev/javascript/prelude.mjs";

export function process(
  vault: Vault,
  file: TFile,
  callback: (data: string) => string,
): void {
  vault.process(file, callback);
}

export function get_file_by_path(
  vault: Vault,
  path: string,
): Result<TFile, null> {
  let file = vault.getFileByPath(path);
  if (file) return new Ok(file);
  else return new Error(null);
}

export function on(
  vault: Vault,
  event: any,
  callback: (file: TAbstractFile) => void,
): void {
  vault.on(event, function (file) {
    callback(file);
  });
}
