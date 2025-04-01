import board_config_form
import components
import gleam/option.{None, Some}
import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html as h
import trill/board_view
import trill/defs.{type Model, type Msg}
import trill/toolbar

pub fn view(model: Model) -> Element(Msg) {
  case model.toolbar {
    Some(_toolbar) -> board_view(model)
    None -> blank_view(model)
  }
}

fn blank_view(_model: Model) -> Element(Msg) {
  h.div(
    [attr.class("flex w-2/3 max-w-2xl justify-self-center items-center h-full")],
    [
      board_config_form.element(
        components.name,
        None,
        "user-submitted-new-board-form",
        "Create Board",
      ),
    ],
  )
}

fn board_view(model: Model) -> Element(Msg) {
  let toolbar =
    model.toolbar
    |> option.map(toolbar.view)
    |> option.unwrap(element.none())
    |> element.map(defs.ToolbarMsg)

  let board_view =
    model.board_view
    |> option.map(board_view.view)
    |> option.unwrap(element.none())
    |> element.map(defs.BoardViewMsg)

  h.div([], [toolbar, board_view])
}
