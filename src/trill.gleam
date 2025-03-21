import board.{type Board, type Card, Card}
import ffi/dataview.{type Page, Page}
import ffi/obsidian/file_manager.{type FileManager}
import ffi/obsidian/plugin.{type Plugin}
import ffi/obsidian/vault.{type Vault}
import ffi/obsidian/workspace.{type Workspace}
import ffi/plinth_ext/element as pxelement
import ffi/plinth_ext/event as pxevent
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import lustre.{type App}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import plinth/browser/element as pelement
import plinth/browser/event.{type Event as PEvent} as pevent

// TODO Extract a Board module

pub const view_name = "trill"

pub fn app() -> App(Plugin, Model, Msg) {
  lustre.application(init, update, view)
}

pub type Model {
  Model(
    file_manager: FileManager,
    plugin: Plugin,
    vault: Vault,
    workspace: Workspace,
    query: String,
    board: Board(String, Page),
  )
}

const null_status = "none"

pub const statuses = [
  null_status,
  "inbox",
  "ideas",
  "needs-research",
  "ready",
  "done",
]

pub fn init(plugin) -> #(Model, Effect(Msg)) {
  // let query = "!\"templates\" AND (#projects OR #task)"
  let query = "!\"templates\" AND (#test-trill)"

  let pages =
    query
    |> dataview.pages()

  let board =
    board.new_board(
      group_keys: statuses,
      cards: pages,
      group_key_fn: fn(page) { result.unwrap(page.status, null_status) },
      update_group_key_fn: fn(page, new_status) {
        let status = case new_status {
          s if s == null_status -> Error(null_status)
          s -> Ok(s)
        }
        Page(..page, status:)
      },
    )

  let model =
    Model(
      file_manager: plugin.get_file_manager(plugin),
      plugin: plugin,
      vault: plugin.get_vault(plugin),
      workspace: plugin.get_workspace(plugin),
      query: query,
      board: board,
    )

  #(model, effect.none())
}

pub type Msg {
  UserClickedInternalLink(path: String)
  UserHoveredInternalLink(event: Dynamic, path: String)
  UserStartedDraggingCard(event: Dynamic, card: Card(Page))
  UserStoppedDraggingCard(event: Dynamic)
  UserDraggedCardOverTarget(event: PEvent(Dynamic), over: Card(Page))
  UserDraggedCardOverColumn(event: PEvent(Dynamic), over: String)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let #(model, effect) = case msg {
    UserClickedInternalLink(path) -> #(
      model,
      effect.from(fn(_) {
        workspace.open_link_text(model.workspace, path, "tab")
      }),
    )

    UserHoveredInternalLink(event, path) -> #(
      model,
      effect.from(fn(_) {
        workspace.trigger_hover_link(model.workspace, event, view_name, path)
      }),
    )

    UserStartedDraggingCard(_event, card) -> {
      let assert Card(page) = card

      #(
        Model(..model, board: board.start_dragging(model.board, page)),
        effect.none(),
      )
    }

    UserStoppedDraggingCard(_event) -> {
      let assert Some(Card(page)) = model.board.dragging
      let #(board, new_status) = board.drop(model.board)

      let effect = case new_status == board.group_key_fn(page) {
        True -> effect.none()
        False ->
          effect.from(fn(_) {
            case vault.get_file_by_path(model.vault, page.path) {
              Error(_) -> Nil
              Ok(file) ->
                file_manager.process_front_matter(
                  model.file_manager,
                  file,
                  fn(_yaml) {
                    case new_status == null_status {
                      True -> [#("status", None)]
                      False -> [#("status", Some(new_status))]
                    }
                  },
                )
            }
            Nil
          })
      }

      #(Model(..model, board: board), effect)
    }

    UserDraggedCardOverTarget(event, over_card) -> {
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
        Model(..model, board: board.drag_over(model.board, over_page, after)),
        effect.none(),
      )
    }

    UserDraggedCardOverColumn(_event, over_column) -> {
      #(
        Model(..model, board: board.drag_over_column(model.board, over_column)),
        effect.none(),
      )
    }
  }

  #(model, effect)
}

pub fn view(model: Model) -> Element(Msg) {
  html.div(
    [attribute.class("flex h-full")],
    list.map(model.board.group_keys, fn(status) {
      let assert Ok(cards) = dict.get(model.board.groups, status)
      let column_droppable = case list.length(cards) {
        0 ->
          event.on("dragover", fn(event) {
            let assert Ok(event) = pevent.cast_event(event)
            Ok(UserDraggedCardOverColumn(event, status))
          })

        _ -> attribute.none()
      }

      html.div(
        [
          attribute.class("min-w-80 max-w-80 mr-4 height-full"),
          column_droppable,
        ],
        {
          list.append(
            [html.div([attribute.class("mb-2")], [html.text(status)])],
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

                _ -> attribute.none()
              }

              html.div(
                [
                  attribute.class(
                    "bg-(--background-secondary) mb-2 p-4 rounded-md",
                  ),
                  attribute.attribute("draggable", "true"),
                  event.on("dragstart", fn(event) {
                    Ok(UserStartedDraggingCard(event, card))
                  }),
                  event.on("dragend", fn(event) {
                    Ok(UserStoppedDraggingCard(event))
                  }),
                  dragover,
                ],
                [
                  html.a(
                    [
                      attribute.class("internal-link"),
                      attribute.class(invisible),
                      attribute.href(page.path),
                      event.on_click(UserClickedInternalLink(page.path)),
                      event.on("mouseover", fn(event) {
                        Ok(UserHoveredInternalLink(event, page.path))
                      }),
                    ],
                    [html.text(page.title)],
                  ),
                  html.div([attribute.class(invisible)], [html.text(page.path)]),
                  html.div([attribute.class(invisible)], [
                    html.text(result.unwrap(page.status, null_status)),
                  ]),
                ],
              )
            })
              |> list.append([
                html.div(
                  [
                    attribute.class("h-full"),
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
