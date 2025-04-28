import lustre/attribute.{attribute}
import lustre/element
import lustre/element/svg

pub fn icon(name) {
  case name {
    "chevron-down" ->
      svg.svg(
        [
          attribute.class(
            "svg-icon lucide lucide-chevron-down-icon lucide-chevron-down",
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
        [svg.path([attribute("d", "m6 9 6 6 6-6")])],
      )

    "chevron-up" ->
      svg.svg(
        [
          attribute.class(
            "svg-icon lucide lucide-chevron-up-icon lucide-chevron-up",
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
        [svg.path([attribute("d", "m18 15-6-6-6 6")])],
      )

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

    "funnel" ->
      svg.svg(
        [
          attribute.class("svg-icon lucide lucide-funnel-icon lucide-funnel"),
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
          svg.path([
            attribute(
              "d",
              "M10 20a1 1 0 0 0 .553.895l2 1A1 1 0 0 0 14 21v-7a2 2 0 0 1 .517-1.341L21.74 4.67A1 1 0 0 0 21 3H3a1 1 0 0 0-.742 1.67l7.225 7.989A2 2 0 0 1 10 14z",
            ),
          ]),
        ],
      )

    "kanban" ->
      svg.svg(
        [
          attribute.class("svg-icon lucide lucide-kanban-icon lucide-kanban"),
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
          svg.path([attribute("d", "M6 5v11")]),
          svg.path([attribute("d", "M12 5v6")]),
          svg.path([attribute("d", "M18 5v14")]),
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

    "square-plus" ->
      svg.svg(
        [
          attribute.class(
            "svg-icon lucide lucide-square-plus-icon lucide-square-plus",
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
          svg.path([attribute("d", "M8 12h8")]),
          svg.path([attribute("d", "M12 8v8")]),
        ],
      )

    "square-x" ->
      svg.svg(
        [
          attribute.class(
            "svg-icon lucide lucide-square-x-icon lucide-square-x",
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
            attribute("ry", "2"),
            attribute("rx", "2"),
            attribute("y", "3"),
            attribute("x", "3"),
            attribute("height", "18"),
            attribute("width", "18"),
          ]),
          svg.path([attribute("d", "m15 9-6 6")]),
          svg.path([attribute("d", "m9 9 6 6")]),
        ],
      )

    "x" ->
      svg.svg(
        [
          attribute.class("svg-icon lucide lucide-x-icon lucide-x"),
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
          svg.path([attribute("d", "M18 6 6 18")]),
          svg.path([attribute("d", "m6 6 12 12")]),
        ],
      )

    _ -> element.none()
  }
}
