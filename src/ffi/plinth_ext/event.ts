// import { List, Ok, Error } from "build/dev/javascript/prelude.mjs"
import { Coords } from "build/dev/javascript/obsidian_plugin/ffi/plinth_ext/event.mjs";

export function get_client_coords(ev: MouseEvent) {
  return new Coords(ev.clientX, ev.clientY);
}
