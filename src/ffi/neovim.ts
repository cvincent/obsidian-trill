import { TFile, Vault } from "obsidian";

export async function open_file(vault: Vault, neovim: any, file: TFile) {
  await neovim
    .newInstance(vault.adapter)
    .then(() => setTimeout(() => neovim.openFile(file), 1000));
}
