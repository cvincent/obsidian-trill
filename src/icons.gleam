import lustre/attribute.{attribute}
import lustre/element
import lustre/element/svg

pub fn icon(name) {
  case name {
    "ellipsis-vertical" ->
      svg.svg(
        [
          attribute.class("svg-icon lucide lucide-ellipsis-vertical"),
          attribute("stroke-linejoin", "round"),
          attribute("stroke-linecap", "round"),
          attribute("stroke-width", "2"),
          attribute("stroke", "currentColor"),
          attribute("fill", "none"),
          attribute("viewBox", "0 0 24 24"),
          attribute("height", "24"),
          attribute("width", "24"),
          attribute("xmlns", "http://www.w3.org/2000/svg"),
        ],
        [
          svg.circle([
            attribute("r", "1"),
            attribute("cy", "12"),
            attribute("cx", "12"),
          ]),
          svg.circle([
            attribute("r", "1"),
            attribute("cy", "5"),
            attribute("cx", "12"),
          ]),
          svg.circle([
            attribute("r", "1"),
            attribute("cy", "19"),
            attribute("cx", "12"),
          ]),
        ],
      )

    "square-check" ->
      svg.svg(
        [
          attribute.class(
            "svg-icon lucide lucide-square-check-icon lucide-square-check",
          ),
          attribute("stroke-linejoin", "round"),
          attribute("stroke-linecap", "round"),
          attribute("stroke-width", "2"),
          attribute("stroke", "currentColor"),
          attribute("fill", "none"),
          attribute("viewBox", "0 0 24 24"),
          attribute("height", "24"),
          attribute("width", "24"),
          attribute("xmlns", "http://www.w3.org/2000/svg"),
        ],
        [
          svg.rect([
            attribute("rx", "2"),
            attribute("y", "3"),
            attribute("x", "3"),
            attribute("height", "18"),
            attribute("width", "18"),
          ]),
          svg.path([attribute("d", "m9 12 2 2 4-4")]),
        ],
      )

    _ -> element.none()
  }
}
