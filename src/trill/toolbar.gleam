import board_config.{type BoardConfig, BoardConfig}
import board_config_form
import card_filter.{type CardFilter, CardFilter}
import components
import confirm_modal
import context_menu
import ffi/dataview
import ffi/obsidian/modal.{type Modal}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import icons
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event
import obsidian_context.{type ObsidianContext}
import util.{guard_element}

pub const user_submitted_new_board_form = "user-submitted-new-board-form"

pub const user_submitted_edit_board_form = "user-submitted-edit-board-form"

pub const user_clicked_delete_board_confirm = "user-clicked-delete-board-confirm"

pub const user_clicked_delete_board_cancel = "user-clicked-delete-board-cancel"

pub type Model {
  Model(
    obs: ObsidianContext,
    board_config: BoardConfig,
    board_configs: List(BoardConfig),
    show_filter: Bool,
    board_tags: List(String),
  )
}

pub fn maybe_toolbar(
  obs: ObsidianContext,
  board_configs: List(BoardConfig),
) -> Option(Model) {
  case list.first(board_configs) {
    Ok(board_config) ->
      Some(Model(
        obs:,
        board_configs:,
        board_config:,
        show_filter: False,
        board_tags: tags_for_query(board_config.query),
      ))
    Error(Nil) -> None
  }
}

pub fn add_board_config(toolbar: Model, board_config: BoardConfig) -> Model {
  let board_configs =
    [board_config, ..toolbar.board_configs]
    |> list.sort(fn(a, b) { string.compare(a.name, b.name) })
  Model(..toolbar, board_configs:)
}

pub fn set_current_board_config(
  toolbar: Model,
  board_config: BoardConfig,
) -> Model {
  let board_configs =
    toolbar.board_configs
    |> list.map(fn(bc) {
      case bc {
        bc if bc.id == board_config.id -> board_config
        bc -> bc
      }
    })

  Model(
    ..toolbar,
    board_configs:,
    board_config: board_config,
    board_tags: tags_for_query(board_config.query),
  )
}

pub fn delete_current_board_config(toolbar: Model) -> Option(Model) {
  let board_configs =
    list.filter(toolbar.board_configs, fn(bc) { bc != toolbar.board_config })

  case list.first(toolbar.board_configs) {
    Ok(board_config) ->
      Some(
        Model(..toolbar, board_configs:)
        |> set_current_board_config(board_config),
      )
    Error(Nil) -> None
  }
}

fn tags_for_query(query: String) -> List(String) {
  dataview.pages(query)
  |> list.flat_map(fn(p) { p.tags })
  |> list.unique()
}

pub type Msg {
  UserSelectedBoardConfig(id: String)
  UserClickedBoardMenu(ev: Dynamic)
  UserClickedNewBoard
  UserClickedDuplicateBoard
  UserClickedEditBoard
  UserClickedDeleteBoard
  ToolbarDisplayedModal(Modal)

  UserClickedToggleFilter(ev: Dynamic)
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
    UserSelectedBoardConfig(id) -> {
      let board_config = list.find(model.board_configs, fn(bc) { bc.id == id })

      case board_config {
        Ok(board_config) -> #(
          set_current_board_config(model, board_config),
          effect.none(),
        )
        Error(_) -> #(model, effect.none())
      }
    }

    UserClickedBoardMenu(ev) ->
      #(model, effect.none())
      |> show_context_menu(ev, [
        #("New board", "file-plus-2", UserClickedNewBoard),
        #("Duplicate board", "copy-plus", UserClickedDuplicateBoard),
        #("Edit board", "pencil", UserClickedEditBoard),
        #("Delete board", "trash-2", UserClickedDeleteBoard),
      ])

    UserClickedNewBoard ->
      #(model, effect.none())
      |> show_board_config_form_modal(
        board_config.new(),
        user_submitted_new_board_form,
        "Create Board",
      )

    UserClickedDuplicateBoard ->
      #(model, effect.none())
      |> show_board_config_form_modal(
        BoardConfig(
          ..model.board_config,
          name: model.board_config.name <> " Copy",
        ),
        user_submitted_new_board_form,
        "Create Board",
      )

    UserClickedEditBoard ->
      #(model, effect.none())
      |> show_board_config_form_modal(
        model.board_config,
        user_submitted_edit_board_form,
        "Save Board",
      )

    UserClickedDeleteBoard ->
      #(model, effect.none())
      |> show_confirm_delete_modal()

    ToolbarDisplayedModal(_modal) -> #(model, effect.none())

    UserClickedToggleFilter(_) -> #(
      Model(..model, show_filter: !model.show_filter),
      effect.none(),
    )

    UserUpdatedFilterSearch(search) -> {
      let search = case search {
        "" -> None
        search -> Some(search)
      }

      #(model, effect.none())
      |> update_filter(CardFilter(..model.board_config.filter, search:))
    }

    UserClickedClearFilterSearch ->
      #(model, effect.none())
      |> update_filter(CardFilter(..model.board_config.filter, search: None))

    UserClickedToggleFilterTag(ev, tag) -> {
      let ctrl =
        ev
        |> decode.run(decode.at(["ctrlKey"], decode.bool))
        |> result.unwrap(False)

      // TODO: I don't love these three sequential case statements, can we do
      // better?
      let tags = case model.board_config.filter.tags {
        [] -> list.filter(model.board_tags, fn(t) { t != tag })
        tags ->
          case list.contains(tags, tag) {
            True -> list.filter(tags, fn(t) { t != tag })
            False -> list.append(tags, [tag])
          }
      }

      let tags = case ctrl {
        True -> [tag]
        False -> tags
      }

      let tags = case list.all(model.board_tags, list.contains(tags, _)) {
        True -> []
        _ -> tags
      }

      #(model, effect.none())
      |> update_filter(CardFilter(..model.board_config.filter, tags:))
    }

    UserClickedSelectAllFilterTags ->
      #(model, effect.none())
      |> update_filter(CardFilter(..model.board_config.filter, tags: []))

    UserClickedToggleFilterEnabled ->
      #(model, effect.none())
      |> update_filter(
        CardFilter(
          ..model.board_config.filter,
          enabled: !model.board_config.filter.enabled,
        ),
      )
  }
}

fn show_context_menu(
  update: Update,
  click_event: Dynamic,
  menu: List(#(String, String, Msg)),
) -> Update {
  let #(model, effects) = update

  let effect =
    effect.from(fn(disp) {
      let menu =
        menu
        |> list.map(fn(item) {
          let #(name, icon, msg) = item
          #(name, icon, fn() { disp(msg) })
        })
      context_menu.show(click_event, menu)
      Nil
    })

  #(model, effect.batch([effect, effects]))
}

fn show_board_config_form_modal(
  update: Update,
  board_config: BoardConfig,
  emit_submit: String,
  submit_label: String,
) -> Update {
  let #(model, effects) = update

  let form =
    board_config_form.element(
      components.name,
      Some(board_config),
      emit_submit,
      submit_label,
    )

  let effect =
    modal.with_element(model.obs.app, form)
    |> display_modal()

  #(model, effect.batch([effect, effects]))
}

fn show_confirm_delete_modal(update: Update) -> Update {
  let #(model, effects) = update

  let effect =
    modal.with_element(
      model.obs.app,
      confirm_modal.element(
        components.name,
        "Are you sure you want to delete " <> model.board_config.name <> "?",
        "Delete",
        user_clicked_delete_board_confirm,
        // TODO: Can we have modals dismiss themselves?
        user_clicked_delete_board_cancel,
      ),
    )
    |> display_modal()

  #(model, effect.batch([effect, effects]))
}

fn update_filter(update: Update, filter: CardFilter) -> Update {
  #(
    Model(
      ..update.0,
      board_config: BoardConfig(..{ update.0 }.board_config, filter:),
    ),
    update.1,
  )
}

fn display_modal(modal: Modal) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    modal.open(modal)
    dispatch(ToolbarDisplayedModal(modal))
  })
}

pub fn view(model: Model) -> Element(Msg) {
  h.div([], [
    h.div([attr.class("flex justify-between mb-4 gap-2")], [
      toolbar_left(model),
      toolbar_right(model),
    ]),
    filter(model),
  ])
}

fn toolbar_left(model: Model) -> Element(Msg) {
  h.div([attr.class("flex justify-start gap-2")], [
    h.select(
      [attr.class("dropdown"), event.on_input(UserSelectedBoardConfig)],
      list.map(model.board_configs, fn(board_config) {
        h.option(
          [
            attr.selected(board_config.id == model.board_config.id),
            attr.value(board_config.id),
          ],
          board_config.name,
        )
      }),
    ),
    h.div(
      [
        attr.class(
          "clickable-icon [--icon-size:var(--icon-s)] [--icon-stroke:var(--icon-s-stroke-width)]",
        ),
        event.on("click", fn(ev) { Ok(UserClickedBoardMenu(ev)) }),
      ],
      [icons.icon("ellipsis-vertical")],
    ),
  ])
}

fn toolbar_right(model: Model) -> Element(Msg) {
  let filter_icon_class =
    "clickable-icon [--icon-size:var(--icon-xs)] [--icon-stroke:var(--icon-xs-stroke-width)] justify-self-end"

  let filter_icon_class = case
    card_filter.any(model.board_config.filter),
    model.show_filter
  {
    True, _ -> filter_icon_class <> " [--icon-color:var(--color-orange)]"
    _, True -> filter_icon_class <> " [--icon-color:var(--icon-color-active)]"
    _, _ -> filter_icon_class
  }

  h.div([attr.class("flex justify-end gap-2")], [
    h.div(
      [
        attr.class(filter_icon_class),
        event.on("click", fn(ev) { Ok(UserClickedToggleFilter(ev)) }),
      ],
      [icons.icon("funnel")],
    ),
  ])
}

fn filter(model: Model) -> Element(Msg) {
  let filter = model.board_config.filter

  case model.show_filter {
    False -> element.none()
    True ->
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
                      attr.classes([#("is-enabled", filter.enabled)]),
                    ],
                    [
                      h.input([
                        attr.type_("checkbox"),
                        attr.checked(filter.enabled),
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
                    attr.value(option.unwrap(filter.search, "")),
                    event.on_input(UserUpdatedFilterSearch),
                  ]),
                  guard_element(
                    option.is_some(filter.search),
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
                        let checked = case filter.tags {
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
}
