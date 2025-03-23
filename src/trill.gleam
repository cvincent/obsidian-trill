import board.{type Board, type Card, Card}
import board_config.{type BoardConfig, BoardConfig}
import components
import ffi/console
import ffi/dataview.{type Page, Page}
import ffi/obsidian/file_manager
import ffi/obsidian/plugin
import ffi/obsidian/vault
import ffi/obsidian/workspace
import ffi/plinth_ext/element as pxelement
import ffi/plinth_ext/event as pxevent
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre.{type App}
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event
import obsidian_context.{type ObsidianContext}
import plinth/browser/element as pelement
import plinth/browser/event.{type Event as PEvent} as pevent

// TODO Extract a Board module

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
      new_board_from_config(board_config)
    })

  let model = Model(board_configs:, board_config:, board:, obsidian_context:)

  #(model, effect.none())
}

pub type Msg {
  UserClickedInternalLink(path: String)
  UserHoveredInternalLink(event: Dynamic, path: String)
  UserStartedDraggingCard(event: Dynamic, card: Card(Page))
  UserStoppedDraggingCard(event: Dynamic)
  UserDraggedCardOverTarget(event: PEvent(Dynamic), over: Card(Page))
  UserDraggedCardOverColumn(event: PEvent(Dynamic), over: String)

  UserSubmittedNewBoardForm(event: Dynamic)
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

      #(
        Model(..model, board: Some(board.start_dragging(board, page))),
        effect.none(),
      )
    }

    UserStoppedDraggingCard(_event) -> {
      let assert Some(board) = model.board
      let assert Some(Card(page)) = board.dragging
      let #(board, new_status) = board.drop(board)

      let effect = case new_status == board.group_key_fn(page) {
        True -> effect.none()
        False ->
          effect.from(fn(_) {
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

      #(
        Model(..model, board: Some(board.drag_over(board, over_page, after))),
        effect.none(),
      )
    }

    UserDraggedCardOverColumn(_event, over_column) -> {
      let assert Some(board) = model.board

      #(
        Model(..model, board: Some(board.drag_over_column(board, over_column))),
        effect.none(),
      )
    }

    UserSubmittedNewBoardForm(ev) -> {
      let assert Ok(new_board_config) =
        decode.run(ev, decode.at(["detail"], board_config.from_json()))
      #(model, effect.none())
      let board_configs =
        [new_board_config, ..model.board_configs]
        |> list.sort(fn(a, b) { string.compare(a.name, b.name) })

      let save_data = board_config.list_to_json(board_configs)
      plugin.save_data(model.obsidian_context.plugin, save_data)

      #(
        Model(
          ..model,
          board_configs:,
          board_config: Some(new_board_config),
          board: Some(new_board_from_config(new_board_config)),
        ),
        effect.none(),
      )
    }
  }
}

fn new_board_from_config(board_config: BoardConfig) {
  board.new_board(
    group_keys: board_config.statuses,
    cards: dataview.pages(board_config.query),
    group_key_fn:,
    update_group_key_fn:,
  )
}

pub fn view(model: Model) -> Element(Msg) {
  h.div(
    [
      event.on("user-submitted-new-board-form", fn(payload) {
        Ok(UserSubmittedNewBoardForm(payload))
      }),
    ],
    [
      case model.board_config {
        Some(_board_config) -> board_view(model)
        None ->
          element.element(
            components.name("board-config-form"),
            [
              attr.attribute("emit-submit", "user-submitted-new-board-form"),
              attr.attribute("submit-label", "Create Board"),
            ],
            [],
          )
      },
    ],
  )
}

fn board_view(model: Model) -> Element(Msg) {
  let assert Some(board) = model.board

  h.div(
    [attr.class("flex h-full")],
    list.map(board.group_keys, fn(status) {
      let assert Ok(cards) = dict.get(board.groups, status)
      let column_droppable = case list.length(cards) {
        0 ->
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
                  event.on("dragover", fn(event) {
                    let assert Ok(event) = pevent.cast_event(event)
                    Ok(UserDraggedCardOverTarget(event, card))
                  })

                _ -> attr.none()
              }

              h.div(
                [
                  attr.class("bg-(--background-secondary) mb-2 p-4 rounded-md"),
                  attr.attribute("draggable", "true"),
                  event.on("dragstart", fn(event) {
                    Ok(UserStartedDraggingCard(event, card))
                  }),
                  event.on("dragend", fn(event) {
                    Ok(UserStoppedDraggingCard(event))
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
                      event.on("mouseover", fn(event) {
                        Ok(UserHoveredInternalLink(event, page.path))
                      }),
                    ],
                    [h.text(page.title)],
                  ),
                  h.div([attr.class(invisible)], [h.text(page.path)]),
                  h.div([attr.class(invisible)], [
                    h.text(result.unwrap(page.status, board_config.null_status)),
                  ]),
                ],
              )
            })
              |> list.append([
                h.div(
                  [
                    attr.class("h-full"),
                    event.on("dragover", fn(event) {
                      let assert Ok(event) = pevent.cast_event(event)
                      Ok(UserDraggedCardOverColumn(event, status))
                    }),
                  ],
                  [],
                ),
              ]),
          )
        },
      )
    }),
  )
}
