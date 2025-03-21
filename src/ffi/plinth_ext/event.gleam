import gleam/dynamic.{type Dynamic}
import plinth/browser/event.{type Event}

pub type Coords {
  Coords(x: Int, y: Int)
}

@external(javascript, "./event.ts", "get_client_coords")
pub fn get_client_coords(el: Event(Dynamic)) -> Coords
