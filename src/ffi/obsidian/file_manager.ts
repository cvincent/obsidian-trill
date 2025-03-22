import { FileManager, TFile } from "obsidian";
import { List } from "build/dev/javascript/prelude.mjs";

export function process_front_matter(
  fm: FileManager,
  file: TFile,
  callback: (frontmatter: object) => List<[string, { 0?: string }]>,
): void {
  fm.processFrontMatter(file, (frontmatter) => {
    let updates = callback(frontmatter).toArray();

    for (let [key, val] of updates) {
      if (val[0]) {
        frontmatter[key] = val[0];
      } else {
        delete frontmatter[key];
      }
      console.log([key, val]);
    }
  });
}
