// import { List, Ok, Error } from "build/dev/javascript/prelude.mjs"
import { Rect } from "build/dev/javascript/obsidian_plugin/ffi/plinth_ext/element.mjs";

export function get_bounding_client_rect(el: Element) {
  let rect = el.getBoundingClientRect();
  return new Rect(
    rect.x,
    rect.y,
    rect.width,
    rect.height,
    rect.top,
    rect.right,
    rect.bottom,
    rect.left,
  );
}
