import board.{type Board, type Card, Card}
import board_config.{type BoardConfig, BoardConfig}
import ffi/dataview.{type Page, Page}
import ffi/obsidian/file_manager.{type FileManager}
import ffi/obsidian/plugin.{type Plugin}
import ffi/obsidian/vault.{type Vault}
import ffi/obsidian/workspace.{type Workspace}
import ffi/plinth_ext/element as pxelement
import ffi/plinth_ext/event as pxevent
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
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
import plinth/browser/element as pelement
import plinth/browser/event.{type Event as PEvent} as pevent
import plinth/javascript/console

// TODO Extract a Board module

pub const view_name = "trill"

pub fn app() -> App(#(Plugin, Dynamic), Model, Msg) {
  lustre.application(init, update, view)
}

pub type Model {
  Model(
    file_manager: FileManager,
    plugin: Plugin,
    vault: Vault,
    workspace: Workspace,
    new_board_config: BoardConfig,
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

pub fn init(data) -> #(Model, Effect(Msg)) {
  let #(plugin, data) = data

  let board_configs = board_config.list_from_json(data)

  let board_config =
    board_configs
    |> list.first()
    |> result.map(fn(board_config) { Some(board_config) })
    |> result.unwrap(None)

  let board =
    option.map(board_config, fn(board_config) {
      new_board_from_config(board_config)
    })

  let model =
    Model(
      board_configs:,
      board_config:,
      board:,
      plugin: plugin,
      file_manager: plugin.get_file_manager(plugin),
      vault: plugin.get_vault(plugin),
      workspace: plugin.get_workspace(plugin),
      new_board_config: board_config.new_board_config,
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

  UserUpdatedNewBoardName(new_board_name: String)
  UserUpdatedNewBoardQuery(new_board_query: String)
  UserClickedCreateProject
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
            case vault.get_file_by_path(model.vault, page.path) {
              Error(_) -> Nil
              Ok(file) ->
                file_manager.process_front_matter(
                  model.file_manager,
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

    UserUpdatedNewBoardName(new_board_name) -> #(
      Model(
        ..model,
        new_board_config: BoardConfig(
          ..model.new_board_config,
          name: new_board_name,
        ),
      ),
      effect.none(),
    )

    UserUpdatedNewBoardQuery(new_board_query) -> #(
      Model(
        ..model,
        new_board_config: BoardConfig(
          ..model.new_board_config,
          query: new_board_query,
        ),
      ),
      effect.none(),
    )

    UserClickedCreateProject -> {
      let board_configs =
        [model.new_board_config, ..model.board_configs]
        |> list.sort(fn(a, b) { string.compare(a.name, b.name) })

      let save_data = board_config.list_to_json(board_configs)
      plugin.save_data(model.plugin, save_data)

      #(
        Model(
          ..model,
          board_configs:,
          new_board_config: board_config.new_board_config,
          board_config: Some(model.new_board_config),
          board: Some(new_board_from_config(model.new_board_config)),
        ),
        effect.none(),
      )
    }
  }

  #(model, effect)
}

fn new_board_from_config(board_config: BoardConfig) {
  board.new_board(
    group_keys: board_config.statuses,
    cards: dataview.pages(board_config.query),
    group_key_fn:,
    update_group_key_fn:,
  )
}

// TODO: Extract this to board_config; the caller will need to augment the query
// error, as board and board_config are agnostic about the inner card value as
// well as about how queries are used
fn validate_board_config(
  board_config: BoardConfig,
) -> Dict(String, Result(Option(String), String)) {
  let name_error = case board_config.name {
    "" -> Error("Must have a name.")
    _ -> Ok(None)
  }

  let query_error = case dataview.pages(board_config.query) {
    [] -> Error("Query returned no notes.")
    pages ->
      Ok(Some(
        "Your query resulted in "
        <> int.to_string(list.length(pages))
        <> " notes.",
      ))
  }

  dict.from_list([#("name", name_error), #("query", query_error)])
}

pub fn view(model: Model) -> Element(Msg) {
  case model.board_config {
    Some(_board_config) -> board_view(model)
    None -> new_board_view(model)
  }
}

fn new_board_view(model: Model) -> Element(Msg) {
  let heading = case model.new_board_config.name {
    "" -> "Create a New Board"
    name -> name
  }

  let errors = validate_board_config(model.new_board_config)

  let enabled = case errors |> dict.values() |> result.all() {
    Error(_) -> attr.disabled(True)
    _ -> attr.none()
  }

  h.div([attr.class("flex h-full items-center justify-center")], [
    h.div([attr.class("w-2/3 max-w-2xl")], [
      h.h1([attr.class("text-center")], [h.text(heading)]),
      text_field(
        "Board name",
        None,
        model.new_board_config.name,
        dict.get(errors, "name"),
        UserUpdatedNewBoardName,
      ),
      text_field(
        "Query",
        Some(
          "This Dataview query will be used to select what notes to display as cards.",
        ),
        model.new_board_config.query,
        dict.get(errors, "query"),
        UserUpdatedNewBoardQuery,
      ),
      h.div([attr.class("flex justify-end mt-4")], [
        h.button([enabled, event.on_click(UserClickedCreateProject)], [
          h.text("Create Board"),
        ]),
      ]),
    ]),
  ])
}

fn text_field(
  label: String,
  description: Option(String),
  value: String,
  message: Result(Result(Option(String), String), Nil),
  update_constructor: fn(String) -> Msg,
) {
  h.div([attr.class("setting-item")], [
    h.div([attr.class("setting-item-info")], [
      h.div([attr.class("setting-item-name")], [h.text(label)]),
      h.div([attr.class("setting-item-description")], [
        case description {
          None -> element.none()
          Some(description) -> h.div([], [h.text(description)])
        },
        field_message(message),
      ]),
    ]),
    h.div([attr.class("setting-item-control")], [
      h.input([
        attr.class("min-w-80"),
        attr.type_("text"),
        attr.value(value),
        event.on_input(update_constructor),
      ]),
    ]),
  ])
}

fn field_message(message: Result(Result(Option(String), String), Nil)) {
  case message {
    Ok(Ok(Some(message))) -> h.div([], [h.text(message)])
    Ok(Error(error)) ->
      h.div([attr.class("text-(--text-error)")], [h.text(error)])
    _ -> h.div([attr.class("whitespace-pre")], [h.text(" ")])
  }
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
