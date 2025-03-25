import { List, Ok, Error } from "build/dev/javascript/prelude.mjs";
import { Page } from "build/dev/javascript/obsidian_plugin/ffi/dataview.mjs";

function dv(): any {
  const win = <any>window;
  return win.app.plugins.plugins.dataview.api;
}

export function pages(query: string): List<Page> {
  return List.fromArray(
    dv()
      .pages(query)
      .map((p: any) => {
        console.log(p);
        return {
          title: p.title || p.file.path,
          path: p.file.path,
          status: p.status ? new Ok(p.status) : new Error("none"),
          original: p,
        };
      }),
  );
}
