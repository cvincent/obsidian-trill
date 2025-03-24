import board.{type Board, type Card, Card}
import board_config.{type BoardConfig, BoardConfig}
import board_config_form
import components
import context_menu
import ffi/console
import ffi/dataview.{type Page, Page}
import ffi/obsidian/file_manager
import ffi/obsidian/modal.{type Modal}
import ffi/obsidian/plugin
import ffi/obsidian/vault
import ffi/obsidian/workspace
import ffi/plinth_ext/element as pxelement
import ffi/plinth_ext/event as pxevent
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import icons
import lustre.{type App}
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event
import obsidian_context.{type ObsidianContext}
import plinth/browser/element as pelement
import plinth/browser/event.{type Event as PEvent} as pevent
import plinth/browser/window

pub const view_name = "trill"

pub fn app() -> App(ObsidianContext, Model, Msg) {
  lustre.application(init, update, view)
}

pub type Model {
  Model(
    obsidian_context: ObsidianContext,
    board_config: Option(BoardConfig),
    board_configs: List(BoardConfig),
    board: Option(Board(String, Page)),
    modal: Option(Modal),
  )
}

fn group_key_fn(page: Page) {
  result.unwrap(page.status, board_config.null_status)
}

fn update_group_key_fn(page: Page, new_status: String) {
  let status = case new_status {
    s if s == board_config.null_status -> Error(board_config.null_status)
    s -> Ok(s)
  }
  Page(..page, status:)
}

pub fn init(obsidian_context: ObsidianContext) -> #(Model, Effect(Msg)) {
  let board_configs = board_config.list_from_json(obsidian_context.saved_data)

  let board_config =
    board_configs
    |> list.first()
    |> result.map(fn(board_config) { Some(board_config) })
    |> result.unwrap(None)

  let board =
    option.map(board_config, fn(board_config) {
      board_from_config(board_config)
    })

  let model =
    Model(board_configs:, board_config:, board:, obsidian_context:, modal: None)

  #(
    model,
    effect.from(fn(dispatch) {
      window.add_event_listener("user-submitted-new-board-form", fn(ev) {
        dispatch(UserSubmittedNewBoardForm(dynamic.from(ev)))
      })

      window.add_event_listener("user-submitted-edit-board-form", fn(ev) {
        dispatch(UserSubmittedEditBoardForm(dynamic.from(ev)))
      })
    }),
  )
}

pub type Msg {
  UserClickedInternalLink(path: String)
  UserHoveredInternalLink(event: Dynamic, path: String)
  UserStartedDraggingCard(event: Dynamic, card: Card(Page))
  UserStoppedDraggingCard(event: Dynamic)
  UserDraggedCardOverTarget(event: PEvent(Dynamic), over: Card(Page))
  UserDraggedCardOverColumn(event: PEvent(Dynamic), over: String)

  UserSubmittedNewBoardForm(event: Dynamic)
  UserClickedBoardMenu(event: Dynamic)
  UserClickedEditBoard
  UserSubmittedEditBoardForm(event: Dynamic)
  UserClickedNewBoard
  UserSelectedBoardConfig(board_config: BoardConfig)
  UserClickedDeleteBoard
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserClickedInternalLink(path) -> #(
      model,
      effect.from(fn(_) {
        workspace.open_link_text(model.obsidian_context.workspace, path, "tab")
      }),
    )

    UserHoveredInternalLink(event, path) -> #(
      model,
      effect.from(fn(_) {
        workspace.trigger_hover_link(
          model.obsidian_context.workspace,
          event,
          view_name,
          path,
        )
      }),
    )

    UserStartedDraggingCard(_event, card) -> {
      let assert Some(board) = model.board
      let assert Card(page) = card

      #(model, [])
      |> update_board(board.start_dragging(board, page))
      |> apply_updates()
    }

    UserStoppedDraggingCard(_event) -> {
      let assert Some(board) = model.board
      let assert Some(Card(page)) = board.dragging
      let #(board, new_status) = board.drop(board)

      let effect = case new_status == board.group_key_fn(page) {
        True -> effect.none()
        False ->
          effect.from(fn(_) {
            // TODO: Encapsulate setting a single Frontmatter property
            case
              vault.get_file_by_path(model.obsidian_context.vault, page.path)
            {
              Error(_) -> Nil
              Ok(file) ->
                file_manager.process_front_matter(
                  model.obsidian_context.file_manager,
                  file,
                  fn(_yaml) {
                    case new_status == board_config.null_status {
                      True -> [#("status", None)]
                      False -> [#("status", Some(new_status))]
                    }
                  },
                )
            }
            Nil
          })
      }

      #(Model(..model, board: Some(board)), effect)
    }

    UserDraggedCardOverTarget(event, over_card) -> {
      let assert Some(board) = model.board
      let assert Card(over_page) = over_card

      let assert Ok(target_card_el) =
        event
        |> pevent.target()
        |> pelement.cast()

      let assert Ok(target_card_el) =
        pelement.closest(target_card_el, "[draggable=true]")

      let target = pxelement.get_bounding_client_rect(target_card_el)
      let mouse = pxevent.get_client_coords(event)

      let top_dist = int.absolute_value(target.top - mouse.y)
      let bot_dist = int.absolute_value(target.top + target.height - mouse.y)

      let after = bot_dist < top_dist

      #(model, [])
      |> update_board(board.drag_over(board, over_page, after))
      |> apply_updates()
    }

    UserDraggedCardOverColumn(_event, over_column) -> {
      let assert Some(board) = model.board

      #(model, [])
      |> update_board(board.drag_over_column(board, over_column))
      |> apply_updates()
    }

    UserSubmittedNewBoardForm(ev) -> {
      let assert Ok(new_board_config) =
        decode.run(ev, decode.at(["detail"], board_config.from_json()))

      let board_configs =
        [new_board_config, ..model.board_configs]
        |> list.sort(fn(a, b) { string.compare(a.name, b.name) })

      #(model, [])
      |> select_board_config(new_board_config)
      |> close_modal()
      |> save_board_configs(board_configs)
      |> apply_updates()
    }

    UserClickedBoardMenu(ev) -> {
      #(model, [])
      |> show_context_menu(ev, [
        #("New board", "file-plus-2", dispatch(UserClickedNewBoard)),
        #("Edit board", "pencil", dispatch(UserClickedEditBoard)),
        #("Delete board", "trash-2", dispatch(UserClickedDeleteBoard)),
      ])
      |> apply_updates()
    }

    UserClickedEditBoard -> {
      #(model, [])
      |> show_board_config_form_modal(
        model.board_config,
        "user-submitted-edit-board-form",
        "Save Board",
      )
      |> apply_updates()
    }

    UserSubmittedEditBoardForm(ev) -> {
      let assert Some(current_board_config) = model.board_config

      let assert Ok(updated_board_config) =
        decode.run(ev, decode.at(["detail"], board_config.from_json()))

      let board_configs =
        model.board_configs
        |> list.map(fn(bc) {
          case bc {
            bc if bc == current_board_config -> updated_board_config
            bc -> bc
          }
        })

      #(model, [])
      |> select_board_config(updated_board_config)
      |> save_board_configs(board_configs)
      |> close_modal()
      |> apply_updates()
    }

    UserClickedNewBoard -> {
      #(model, [])
      |> show_board_config_form_modal(
        None,
        "user-submitted-new-board-form",
        "Create Board",
      )
      |> apply_updates()
    }

    UserSelectedBoardConfig(board_config) -> {
      #(model, [])
      |> select_board_config(board_config)
      |> apply_updates()
    }

    UserClickedDeleteBoard -> {
      #(
        model,
        effect.from(fn(_) {
          let assert Some(board_config) = model.board_config

          modal.with_element(
            model.obsidian_context.app,
            h.div([], [
              h.p([], [
                h.text(
                  "Are you sure you want to delete " <> board_config.name <> "?",
                ),
              ]),
              h.div([attr.class("flex justify-end gap-2")], [
                h.button([], [h.text("Cancel")]),
                h.button([attr.class("mod-destructive")], [h.text("Delete")]),
              ]),
            ]),
          )
          |> modal.open()
        }),
      )
    }
  }
}

// TODO: Listen for changes from Obsidian and update

fn board_from_config(board_config: BoardConfig) {
  board.new_board(
    group_keys: board_config.statuses,
    cards: dataview.pages(board_config.query),
    group_key_fn:,
    update_group_key_fn:,
  )
}

type Update =
  #(Model, List(Effect(Msg)))

fn update_board(update: Update, board) -> Update {
  let #(model, effects) = update
  #(Model(..model, board: Some(board)), effects)
}

fn select_board_config(update: Update, board_config) -> Update {
  let #(model, effects) = update

  #(
    Model(
      ..model,
      board_config: Some(board_config),
      board: Some(board_from_config(board_config)),
    ),
    effects,
  )
}

fn show_context_menu(
  update: Update,
  click_event: Dynamic,
  menu: List(#(String, String, fn(fn(Msg) -> Nil) -> Nil)),
) -> Update {
  let #(model, effects) = update
  let effect = context_menu.show(click_event, menu)
  #(model, [effect, ..effects])
}

fn show_board_config_form_modal(
  update: Update,
  board_config: Option(BoardConfig),
  emit_submit: String,
  submit_label: String,
) -> Update {
  let #(model, effects) = update

  let form =
    board_config_form.element(
      components.name,
      board_config,
      emit_submit,
      submit_label,
    )

  let modal = modal.with_element(model.obsidian_context.app, form)
  let effect = modal.show(modal)

  #(Model(..model, modal: Some(modal)), [effect, ..effects])
}

fn close_modal(update: Update) -> Update {
  let #(model, effects) = update

  let effect = case model.modal {
    Some(modal) -> modal.hide(modal)
    _ -> effect.none()
  }

  #(Model(..model, modal: None), [effect, ..effects])
}

fn save_board_configs(
  update: Update,
  board_configs: List(BoardConfig),
) -> Update {
  let #(model, effects) = update

  let effect =
    effect.from(fn(_) {
      let save_data = board_config.list_to_json(board_configs)
      plugin.save_data(model.obsidian_context.plugin, save_data)
    })

  #(Model(..model, board_configs: board_configs), [effect, ..effects])
}

fn apply_updates(update: Update) -> #(Model, Effect(Msg)) {
  let #(model, effects) = update
  #(model, effect.batch(effects))
}

fn dispatch(msg: Msg) {
  fn(dispatch) { dispatch(msg) }
}

pub fn view(model: Model) -> Element(Msg) {
  case model.board_config {
    Some(_board_config) -> board_view(model)
    None ->
      h.div(
        [
          attr.class(
            "flex w-2/3 max-w-2xl justify-self-center items-center h-full",
          ),
        ],
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
}

fn board_view(model: Model) -> Element(Msg) {
  let assert Some(board) = model.board

  let assert Ok(null_status_cards) =
    dict.get(board.groups, board_config.null_status)

  let group_keys = case null_status_cards {
    [_card, ..] -> board.group_keys
    [] ->
      list.filter(board.group_keys, fn(gk) { gk != board_config.null_status })
  }

  h.div([], [
    h.div([attr.class("flex justify-start mb-2 gap-2")], [
      h.select(
        [
          attr.class("dropdown"),
          event.on_input(fn(value) {
            let assert Ok(board_config) =
              list.find(model.board_configs, fn(bc) { bc.name == value })
            UserSelectedBoardConfig(board_config)
          }),
        ],
        list.map(model.board_configs, fn(board_config) {
          h.option(
            [
              attr.selected(Some(board_config) == model.board_config),
              // TODO: This should be a UUID
              attr.value(board_config.name),
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
    ]),
    h.div(
      [attr.class("flex h-full")],
      list.map(group_keys, fn(status) {
        let assert Ok(cards) = dict.get(board.groups, status)
        let column_droppable = case cards {
          [] ->
            event.on("dragover", fn(event) {
              let assert Ok(event) = pevent.cast_event(event)
              Ok(UserDraggedCardOverColumn(event, status))
            })

          _ -> attr.none()
        }

        h.div(
          [attr.class("min-w-80 max-w-80 mr-4 height-full"), column_droppable],
          {
            list.append(
              [h.div([attr.class("mb-2")], [h.text(status)])],
              list.map(cards, fn(card) {
                let page = card.inner

                let invisible = case card {
                  Card(_) -> ""
                  _ -> "invisible"
                }

                let dragover = case card {
                  Card(_) ->
                    event.on("dragover", fn(ev) {
                      let assert Ok(ev) = pevent.cast_event(ev)
                      Ok(UserDraggedCardOverTarget(ev, card))
                    })

                  _ -> attr.none()
                }

                h.div(
                  [
                    attr.class(
                      "bg-(--background-secondary) mb-2 p-4 rounded-md",
                    ),
                    attr.attribute("draggable", "true"),
                    event.on("dragstart", fn(ev) {
                      Ok(UserStartedDraggingCard(ev, card))
                    }),
                    event.on("dragend", fn(ev) {
                      Ok(UserStoppedDraggingCard(ev))
                    }),
                    dragover,
                  ],
                  [
                    h.a(
                      [
                        attr.class("internal-link"),
                        attr.class(invisible),
                        attr.href(page.path),
                        event.on_click(UserClickedInternalLink(page.path)),
                        event.on("mouseover", fn(ev) {
                          Ok(UserHoveredInternalLink(ev, page.path))
                        }),
                      ],
                      [h.text(page.title)],
                    ),
                    h.div([attr.class(invisible)], [h.text(page.path)]),
                    h.div([attr.class(invisible)], [
                      h.text(result.unwrap(
                        page.status,
                        board_config.null_status,
                      )),
                    ]),
                  ],
                )
              })
                |> list.append([
                  h.div(
                    [
                      attr.class("h-full"),
                      event.on("dragover", fn(ev) {
                        let assert Ok(ev) = pevent.cast_event(ev)
                        Ok(UserDraggedCardOverColumn(ev, status))
                      }),
                    ],
                    [],
                  ),
                ]),
            )
          },
        )
      }),
    ),
  ])
}
