import { List } from "build/dev/javascript/prelude.mjs";

export function jot(tags: List<string>) {
  (window as any).customJS.Helpers.jot(
    null,
    "templates/unique-note-custom.md",
    tags.toArray(),
  );
}
