import board_config.{type ColumnConfig, ColumnConfig}
import gleam/list
import icons
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event

pub type Model {
  Model(columns: List(ColumnConfig))
}

pub type Msg {
  UserClickedAddColumn
  UserClickedRemoveColumn(index: Int)
  UserClickedMoveColumnUp(index: Int)
  UserClickedMoveColumnDown(index: Int)
  UserClickedToggleColumnHideIfEmpty(index: Int)
  UserUpdatedColumnName(index: Int, name: String)
}

type Update =
  #(Model, Effect(Msg))

pub fn update(model: Model, msg: Msg) -> Update {
  case msg {
    UserClickedAddColumn -> #(
      Model(
        columns: list.append(model.columns, [
          ColumnConfig(status: "", hide_if_empty: False),
        ]),
      ),
      effect.none(),
    )

    UserClickedMoveColumnDown(index) -> {
      let #(a, b) = list.split(model.columns, index)
      let assert #([item], b) = list.split(b, 1)
      let assert #([next_item], b) = list.split(b, 1)

      let columns = list.append(a, [next_item, item, ..b])

      #(Model(columns:), effect.none())
    }

    UserClickedMoveColumnUp(index) -> {
      let #(a, b) = list.split(model.columns, index - 1)
      let assert #([item], b) = list.split(b, 1)
      let assert #([next_item], b) = list.split(b, 1)

      let columns = list.append(a, [next_item, item, ..b])

      #(Model(columns:), effect.none())
    }

    UserClickedRemoveColumn(index) -> {
      let #(a, b) = list.split(model.columns, index)
      let b = list.drop(b, 1)
      let columns = list.append(a, b)

      #(Model(columns:), effect.none())
    }

    UserClickedToggleColumnHideIfEmpty(index) -> {
      #(
        Model(
          columns: list.index_map(model.columns, fn(c, i) {
            case i == index {
              False -> c
              True -> ColumnConfig(..c, hide_if_empty: !c.hide_if_empty)
            }
          }),
        ),
        effect.none(),
      )
    }

    UserUpdatedColumnName(index, name) -> #(
      Model(
        columns: list.index_map(model.columns, fn(c, i) {
          case i == index {
            False -> c
            True -> ColumnConfig(..c, status: name)
          }
        }),
      ),
      effect.none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  h.div(
    [
      attr.class(
        "flex justify-around items-start mb-4 bg-(--background-secondary) rounded-md p-2 py-4",
      ),
    ],
    [
      h.div([attr.class("basis-1/2")], [
        h.div([attr.class("flex gap-2 justify-between items-center")], [
          h.div([attr.class("basis-1/2")], [h.text("Status")]),
          h.div([attr.class("text-center")], [h.text("Hide if empty")]),
          h.div([attr.class("flex gap-1 justify-end invisible")], [
            h.button([], [icons.icon("chevron-up")]),
            h.button([], [icons.icon("chevron-down")]),
            h.button([], [icons.icon("x")]),
          ]),
        ]),
        h.div(
          [],
          list.index_map(model.columns, fn(column, i) {
            h.div([attr.class("flex justify-between items-center my-2 gap-2")], [
              h.div([attr.class("basis-1/2")], [
                h.input([
                  attr.class("w-full"),
                  attr.type_("text"),
                  attr.value(column.status),
                  event.on_input(UserUpdatedColumnName(i, _)),
                ]),
              ]),
              h.div(
                [
                  attr.class(
                    "h-[calc(var(--toggle-thumb-height)+var(--toggle-border-width)*2)] text-center",
                  ),
                ],
                [
                  h.div(
                    [
                      attr.class("checkbox-container"),
                      attr.classes([#("is-enabled", column.hide_if_empty)]),
                      event.on_click(UserClickedToggleColumnHideIfEmpty(i)),
                    ],
                    [
                      h.input([
                        attr.type_("checkbox"),
                        attr.checked(column.hide_if_empty),
                      ]),
                    ],
                  ),
                ],
              ),
              h.div([attr.class("flex gap-1 justify-end")], [
                h.button(
                  [
                    event.on_click(UserClickedMoveColumnUp(i)),
                    attr.disabled(i == 0),
                  ],
                  [icons.icon("chevron-up")],
                ),
                h.button(
                  [
                    event.on_click(UserClickedMoveColumnDown(i)),
                    attr.disabled(i == list.length(model.columns) - 1),
                  ],
                  [icons.icon("chevron-down")],
                ),
                h.button([event.on_click(UserClickedRemoveColumn(i))], [
                  icons.icon("x"),
                ]),
              ]),
            ])
          }),
        ),
        h.div([attr.class("flex mt-4 justify-end")], [
          h.button([event.on_click(UserClickedAddColumn)], [
            h.text("Add Column"),
          ]),
        ]),
      ]),
    ],
  )
}
