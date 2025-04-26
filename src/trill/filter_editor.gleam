import card_filter.{type CardFilter, CardFilter}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event
import util.{guard_element}

pub type Model {
  Model(board_tags: List(String), filter: CardFilter)
}

pub type Msg {
  UserUpdatedFilterSearch(search: String)
  UserClickedClearFilterSearch
  UserClickedToggleFilterTag(ev: Dynamic, tag: String)
  UserClickedSelectAllFilterTags
  UserClickedToggleFilterEnabled
}

type Update =
  #(Model, Effect(Msg))

pub fn update(model: Model, msg: Msg) -> Update {
  case msg {
    UserUpdatedFilterSearch(search) -> {
      let search = case search {
        "" -> None
        search -> Some(search)
      }

      #(
        Model(..model, filter: CardFilter(..model.filter, search:)),
        effect.none(),
      )
    }

    UserClickedClearFilterSearch -> #(
      Model(..model, filter: CardFilter(..model.filter, search: None)),
      effect.none(),
    )

    UserClickedToggleFilterTag(ev, tag) -> {
      let ctrl =
        ev
        |> decode.run(decode.at(["ctrlKey"], decode.bool))
        |> result.unwrap(False)

      // Since an empty list means all tags, first determine what toggling this
      // one should do
      let tags = case model.filter.tags {
        [] -> list.filter(model.board_tags, fn(t) { t != tag })
        tags ->
          case list.contains(tags, tag) {
            True -> list.filter(tags, fn(t) { t != tag })
            False -> list.append(tags, [tag])
          }
      }

      // Ctrl overrides to select _only_ this tag
      let tags = case ctrl {
        True -> [tag]
        False -> tags
      }

      // Check if all tags are selected, in which case it's an empty list
      let tags = case list.all(model.board_tags, list.contains(tags, _)) {
        True -> []
        _ -> tags
      }

      #(
        Model(..model, filter: CardFilter(..model.filter, tags:)),
        effect.none(),
      )
    }

    UserClickedSelectAllFilterTags -> #(
      Model(..model, filter: CardFilter(..model.filter, tags: [])),
      effect.none(),
    )

    UserClickedToggleFilterEnabled -> #(
      Model(
        ..model,
        filter: CardFilter(..model.filter, enabled: !model.filter.enabled),
      ),
      effect.none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  h.div([], [
    h.div(
      [
        attr.class(
          "flex justify-around items-start mb-4 bg-(--background-secondary) rounded-md p-2 py-4",
        ),
      ],
      [
        h.div([attr.class("basis-1/3")], [
          h.label(
            [attr.class("flex gap-2 content-center mb-4 cursor-pointer")],
            [
              h.div(
                [
                  attr.class("checkbox-container"),
                  attr.classes([#("is-enabled", model.filter.enabled)]),
                ],
                [
                  h.input([
                    attr.type_("checkbox"),
                    attr.checked(model.filter.enabled),
                    event.on_click(UserClickedToggleFilterEnabled),
                  ]),
                ],
              ),
              h.text("Enable filter"),
            ],
          ),
          h.div([attr.class("search-input-container")], [
            h.div([], [
              h.input([
                attr.class("w-full"),
                attr.type_("search"),
                attr.placeholder("Search..."),
                attr.value(option.unwrap(model.filter.search, "")),
                event.on_input(UserUpdatedFilterSearch),
              ]),
              guard_element(
                option.is_some(model.filter.search),
                h.div(
                  [
                    attr.class("search-input-clear-button"),
                    event.on_click(UserClickedClearFilterSearch),
                  ],
                  [],
                ),
              ),
            ]),
          ]),
        ]),
        h.div([], [
          case list.any(model.board_tags, fn(_) { True }) {
            False -> h.text("No tags")
            True ->
              element.fragment([
                h.div([], [h.text("Tags:")]),
                h.div(
                  [attr.class("max-h-48 overflow-y-auto overflow-x-hidden")],
                  list.map(model.board_tags, fn(t) {
                    let checked = case model.filter.tags {
                      [] -> True
                      tags -> list.contains(tags, t)
                    }

                    h.label(
                      [
                        attr.class(
                          "flex gap-2 content-center my-1 cursor-pointer",
                        ),
                      ],
                      [
                        h.div(
                          [
                            attr.class("checkbox-container"),
                            attr.classes([#("is-enabled", checked)]),
                          ],
                          [
                            h.input([
                              attr.type_("checkbox"),
                              attr.checked(checked),
                              event.on("click", fn(ev) {
                                Ok(UserClickedToggleFilterTag(ev, t))
                              }),
                            ]),
                          ],
                        ),
                        h.text(t),
                      ],
                    )
                  }),
                ),
                h.div([attr.class("text-xs text-right")], [
                  h.a([event.on_click(UserClickedSelectAllFilterTags)], [
                    h.text("select all"),
                  ]),
                ]),
              ])
          },
        ]),
      ],
    ),
  ])
}
