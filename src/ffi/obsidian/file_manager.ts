import { FileManager, TFile } from "obsidian";
import { List } from "build/dev/javascript/prelude.mjs";

export function process_front_matter(
  fm: FileManager,
  file: TFile,
  callback: (frontmatter: object) => List<string[]>,
): void {
  fm.processFrontMatter(file, (frontmatter) => {
    let updates = callback(frontmatter).toArray();

    for (let [key, val] of updates) {
      frontmatter[key] = val;
    }
  });
}
