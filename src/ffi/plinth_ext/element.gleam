import plinth/browser/element.{type Element}

pub type Rect {
  Rect(
    x: Int,
    y: Int,
    width: Int,
    height: Int,
    top: Int,
    right: Int,
    bottom: Int,
    left: Int,
  )
}

@external(javascript, "./element.ts", "get_bounding_client_rect")
pub fn get_bounding_client_rect(el: Element) -> Rect
