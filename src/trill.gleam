import board.{type Board, type Card, Card}
import board_config.{type BoardConfig, BoardConfig}
import board_config_form
import components
import confirm_modal
import context_menu
import ffi/console
import ffi/dataview.{type Page, Page}
import ffi/neovim
import ffi/obsidian/modal.{type Modal}
import ffi/obsidian/plugin
import ffi/obsidian/vault
import ffi/obsidian/workspace
import ffi/plinth_ext/element as pxelement
import ffi/plinth_ext/event as pxevent
import ffi/plinth_ext/global
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
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
import plinth/javascript/global as pglobal
import tempo

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

  let model =
    Model(
      board_configs:,
      board_config:,
      obsidian_context:,
      board: None,
      modal: None,
    )

  #(
    model,
    effect.from(fn(dispatch) {
      window.add_event_listener("user-submitted-new-board-form", fn(ev) {
        dispatch(UserSubmittedNewBoardForm(dynamic.from(ev)))
      })

      window.add_event_listener("user-submitted-edit-board-form", fn(ev) {
        dispatch(UserSubmittedEditBoardForm(dynamic.from(ev)))
      })

      window.add_event_listener("user-clicked-delete-board-confirm", fn(_ev) {
        dispatch(UserClickedDeleteBoardConfirm)
      })

      window.add_event_listener("user-clicked-delete-board-cancel", fn(_ev) {
        dispatch(UserClickedDeleteBoardCancel)
      })

      ["create", "modify", "delete", "rename"]
      |> list.each(fn(event) {
        vault.on(model.obsidian_context.vault, event, fn(_file) {
          let _ =
            global.get_timer_id("file-changed-debounce")
            |> result.try(fn(id) { pglobal.clear_timeout(id) |> Ok() })

          let id =
            pglobal.set_timeout(500, fn() {
              dispatch(ObsidianReportedFileChange)
            })

          global.set_global("file-changed-debounce", id)
        })
      })
    }),
  )
  |> select_board_config(board_config)
}

pub type Msg {
  UserClickedInternalLink(path: String)
  UserHoveredInternalLink(event: Dynamic, path: String)

  UserStartedDraggingCard(event: Dynamic, card: Card(Page))
  UserStoppedDraggingCard(event: Dynamic)
  UserDraggedCardOverTarget(event: PEvent(Dynamic), over: Card(Page))
  UserDraggedCardOverColumn(event: PEvent(Dynamic), over: String)
  UserClickedEditInNeoVim(file: Page)
  UserClickedArchiveAllDone

  UserSelectedBoardConfig(board_config: BoardConfig)
  ObsidianReadPageContents(contents: Dict(String, String))

  UserClickedBoardMenu(event: Dynamic)
  UserClickedNewBoard
  UserClickedDuplicateBoard
  UserClickedEditBoard
  UserClickedDeleteBoard

  UserSubmittedNewBoardForm(event: Dynamic)
  UserSubmittedEditBoardForm(event: Dynamic)

  UserClickedDeleteBoardCancel
  UserClickedDeleteBoardConfirm

  ObsidianReportedFileChange
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

      #(model, effect.none())
      |> update_board(board.start_dragging(board, page))
    }

    UserStoppedDraggingCard(_event) -> {
      let assert Some(board) = model.board
      let assert Some(Card(page)) = board.dragging
      let #(board, new_status) = board.drop(board)

      #(model, effect.none())
      |> update_board(board)
      |> maybe_write_new_status(page, new_status)
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

      #(model, effect.none())
      |> update_board(board.drag_over(board, over_page, after))
    }

    UserDraggedCardOverColumn(_event, over_column) -> {
      let assert Some(board) = model.board

      #(model, effect.none())
      |> update_board(board.drag_over_column(board, over_column))
    }

    UserClickedEditInNeoVim(page) -> {
      let assert Ok(file) =
        vault.get_file_by_path(model.obsidian_context.vault, page.path)

      let assert Ok(neovim) =
        decode.run(
          dynamic.from(model.obsidian_context.app),
          decode.at(
            ["plugins", "plugins", "edit-in-neovim", "neovim"],
            decode.dynamic,
          ),
        )

      neovim.open_file(model.obsidian_context.vault, neovim, file)

      #(model, effect.none())
    }

    UserClickedArchiveAllDone -> {
      let assert Some(board) = model.board

      board.groups
      |> dict.get(board_config.done_status)
      |> result.unwrap([])
      |> list.each(fn(card) {
        let assert Card(page) = card
        obsidian_context.add_tag(model.obsidian_context, page.path, "archive")
        page
      })

      #(model, effect.none())
      |> select_board_config(model.board_config)
    }

    UserSelectedBoardConfig(board_config) -> {
      #(model, effect.none())
      |> select_board_config(Some(board_config))
    }

    ObsidianReadPageContents(contents) -> {
      let assert Some(board) = model.board

      let board =
        board.update_cards(board, fn(card) {
          let assert Card(page) = card
          let content =
            page.path
            |> dict.get(contents, _)
            |> option.from_result()
          Card(Page(..page, content: content))
        })

      #(model, effect.none())
      |> update_board(board)
    }

    UserClickedBoardMenu(ev) -> {
      #(model, effect.none())
      |> show_context_menu(ev, [
        #("New board", "file-plus-2", UserClickedNewBoard),
        #("Duplicate board", "copy-plus", UserClickedDuplicateBoard),
        #("Edit board", "pencil", UserClickedEditBoard),
        #("Delete board", "trash-2", UserClickedDeleteBoard),
      ])
    }

    UserClickedNewBoard -> {
      #(model, effect.none())
      |> show_board_config_form_modal(
        None,
        "user-submitted-new-board-form",
        "Create Board",
      )
    }

    UserClickedDuplicateBoard -> {
      let assert Some(board_config) = model.board_config

      let duplicate =
        BoardConfig(..board_config, name: board_config.name <> " Copy")

      #(model, effect.none())
      |> show_board_config_form_modal(
        Some(duplicate),
        "user-submitted-new-board-form",
        "Create Board",
      )
    }

    UserClickedEditBoard -> {
      #(model, effect.none())
      |> show_board_config_form_modal(
        model.board_config,
        "user-submitted-edit-board-form",
        "Save Board",
      )
    }

    UserClickedDeleteBoard -> {
      let assert Some(board_config) = model.board_config

      let modal =
        confirm_modal.element(
          components.name,
          "Are you sure you want to delete " <> board_config.name <> "?",
          "Delete",
          "user-clicked-delete-board-confirm",
          "user-clicked-delete-board-cancel",
        )
      let modal = modal.with_element(model.obsidian_context.app, modal)

      #(
        Model(..model, modal: Some(modal)),
        effect.from(fn(_) { modal.open(modal) }),
      )
    }

    UserSubmittedNewBoardForm(ev) -> {
      let assert Ok(new_board_config) =
        decode.run(ev, decode.at(["detail"], board_config.from_json()))

      let board_configs =
        [new_board_config, ..model.board_configs]
        |> list.sort(fn(a, b) { string.compare(a.name, b.name) })

      #(model, effect.none())
      |> select_board_config(Some(new_board_config))
      |> close_modal()
      |> save_board_configs(board_configs)
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

      #(model, effect.none())
      |> select_board_config(Some(updated_board_config))
      |> save_board_configs(board_configs)
      |> close_modal()
    }

    UserClickedDeleteBoardConfirm -> {
      let assert Some(current_board_config) = model.board_config
      let new_board_configs =
        list.filter(model.board_configs, fn(bc) { bc != current_board_config })

      let new_current_board_config =
        new_board_configs
        |> list.first()
        |> option.from_result()

      #(model, effect.none())
      |> select_board_config(new_current_board_config)
      |> save_board_configs(new_board_configs)
      |> close_modal()
    }

    UserClickedDeleteBoardCancel -> {
      #(model, effect.none())
      |> close_modal()
    }

    ObsidianReportedFileChange -> {
      case model.board_config {
        Some(board_config) ->
          #(model, effect.none())
          |> select_board_config(Some(board_config))

        _ -> #(model, effect.none())
      }
    }
  }
}

type Update =
  #(Model, Effect(Msg))

fn update_board(update: Update, board) -> Update {
  let #(model, effects) = update
  #(Model(..model, board: Some(board)), effects)
}

fn select_board_config(
  update: Update,
  board_config: Option(BoardConfig),
) -> Update {
  let #(model, effects) = update

  let assert Some(#(board, effect)) =
    option.map(board_config, fn(board_config) {
      let pages = dataview.pages(board_config.query)

      let effect =
        effect.from(fn(dispatch) {
          list.map(pages, fn(page) {
            vault.get_file_by_path(model.obsidian_context.vault, page.path)
            |> result.try(fn(file) {
              vault.cached_read(model.obsidian_context.vault, file)
              |> promise.map(fn(content) { #(page.path, content) })
              |> Ok()
            })
          })
          |> result.values()
          |> promise.await_list()
          |> promise.map(fn(contents) {
            dispatch(ObsidianReadPageContents(dict.from_list(contents)))
          })
          Nil
        })

      let board =
        board.new_board(
          group_keys: board_config.statuses,
          cards: pages,
          group_key_fn:,
          update_group_key_fn:,
        )

      #(board, effect)
    })

  #(
    Model(..model, board_config: board_config, board: Some(board)),
    effect.batch([effect, effects]),
  )
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
  let effect = effect.from(fn(_) { modal.open(modal) })

  #(Model(..model, modal: Some(modal)), effect.batch([effect, effects]))
}

fn close_modal(update: Update) -> Update {
  let #(model, effects) = update

  let effect = case model.modal {
    Some(modal) -> effect.from(fn(_) { modal.close(modal) })
    _ -> effect.none()
  }

  #(Model(..model, modal: None), effect.batch([effect, effects]))
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

  #(
    Model(..model, board_configs: board_configs),
    effect.batch([effect, effects]),
  )
}

fn maybe_write_new_status(
  update: Update,
  page: Page,
  new_status: String,
) -> Update {
  let #(model, effects) = update
  let assert Some(board) = model.board

  let effect = case new_status == board.group_key_fn(page) {
    True -> effect.none()
    False ->
      effect.from(fn(_) {
        let new_status = case new_status {
          new_status if new_status == board_config.null_status -> None
          new_status -> Some(new_status)
        }

        obsidian_context.set_front_matter(
          model.obsidian_context,
          page.path,
          "status",
          new_status,
        )

        case new_status {
          Some(done) if done == board_config.done_status ->
            obsidian_context.set_front_matter(
              model.obsidian_context,
              page.path,
              "done",
              Some(tempo.format_local(tempo.ISO8601Seconds)),
            )
          _ -> {
            obsidian_context.set_front_matter(
              model.obsidian_context,
              page.path,
              "done",
              None,
            )
          }
        }
      })
  }

  #(model, effect.batch([effect, effects]))
}

pub fn view(model: Model) -> Element(Msg) {
  case model.board_config {
    Some(_board_config) -> board_view(model)
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

        let archive_all = case status {
          status if status == board_config.done_status ->
            h.a([event.on_click(UserClickedArchiveAllDone)], [
              h.text("archive all"),
            ])
          _ -> element.none()
        }

        h.div(
          [attr.class("min-w-80 max-w-80 mr-4 height-full"), column_droppable],
          list.append(
            [
              h.div([attr.class("flex gap-2 mb-2")], [
                h.div([], [h.text(status)]),
                h.div([], [archive_all]),
              ]),
            ],
            list.map(cards, fn(card) {
              let page = card.inner

              let tasks =
                decode.run(
                  dynamic.from(page),
                  decode.at(
                    ["original", "file", "tasks"],
                    decode.list(decode.dynamic),
                  ),
                )

              let task_count =
                result.try(tasks, fn(tasks) { Ok(list.length(tasks)) })
                |> result.unwrap(0)

              let done_count =
                result.try(tasks, fn(tasks) {
                  list.count(tasks, fn(task) {
                    Ok("x")
                    == decode.run(task, decode.at(["status"], decode.string))
                  })
                  |> Ok()
                })
                |> result.unwrap(0)

              let task_info_color = case task_count - done_count {
                0 -> attr.class("text-(color:--text-muted)")
                _ -> attr.none()
              }

              let task_info = case task_count {
                task_count if task_count > 0 ->
                  h.div([attr.class("flex gap-1"), task_info_color], [
                    h.div([attr.class("[--icon-size:var(--icon-s)] mt-[1px]")], [
                      icons.icon("square-check"),
                    ]),
                    h.div([attr.class("align-middle")], [
                      h.text(
                        int.to_string(done_count)
                        <> "/"
                        <> int.to_string(task_count),
                      ),
                    ]),
                  ])
                _ -> element.none()
              }

              let content_preview = case page.content {
                Some(content) -> {
                  let assert Ok(re) = regexp.from_string("\\n# .+\\n")
                  case regexp.split(re, content) {
                    [_, content] ->
                      h.div(
                        [
                          attr.class(
                            "[display:-webkit-box] [-webkit-line-clamp:3] [-webkit-box-orient:vertical] overflow-hidden",
                          ),
                        ],
                        [h.text(content)],
                      )
                    _ -> element.none()
                  }
                }
                None -> element.none()
              }

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
                  attr.class("bg-(--background-secondary) mb-2 p-4 rounded-md"),
                  attr.attribute("draggable", "true"),
                  event.on("dragstart", fn(ev) {
                    Ok(UserStartedDraggingCard(ev, card))
                  }),
                  event.on("dragend", fn(ev) { Ok(UserStoppedDraggingCard(ev)) }),
                  dragover,
                ],
                [
                  h.div([attr.class(invisible)], [
                    h.a(
                      [
                        attr.class("internal-link"),
                        attr.href(page.path),
                        event.on_click(UserClickedInternalLink(page.path)),
                        event.on("mouseover", fn(ev) {
                          Ok(UserHoveredInternalLink(ev, page.path))
                        }),
                      ],
                      [h.text(page.title)],
                    ),
                    task_info,
                    content_preview,
                    h.div([attr.class("flex justify-end")], [
                      h.a(
                        [
                          event.on_click(UserClickedEditInNeoVim(page)),
                          attr.class("text-xs"),
                        ],
                        [h.text("nvim")],
                      ),
                    ]),
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
          ),
        )
      }),
    ),
  ])
}
