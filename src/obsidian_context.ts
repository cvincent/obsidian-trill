import { FileManager, Vault } from "obsidian";
import { ObsidianContext } from "build/dev/javascript/obsidian_plugin/obsidian_context.mjs";

export function add_tag(
  obs_ctx: ObsidianContext,
  path: string,
  tag: string,
): void {
  let vault = obs_ctx.vault as Vault;
  let file_manager = obs_ctx.file_manager as FileManager;
  let file = vault.getFileByPath(path);

  if (file) {
    file_manager.processFrontMatter(file, (frontmatter) => {
      frontmatter.tags ||= [];
      frontmatter.tags = [tag, ...frontmatter.tags];
    });
  }
}

export function remove_tag(
  obs_ctx: ObsidianContext,
  path: string,
  tag: string,
): void {
  let vault = obs_ctx.vault as Vault;
  let file_manager = obs_ctx.file_manager as FileManager;
  let file = vault.getFileByPath(path);

  if (file) {
    file_manager.processFrontMatter(file, (frontmatter) => {
      frontmatter.tags ||= [];
      frontmatter.tags.remove(tag);
    });
  }
}
