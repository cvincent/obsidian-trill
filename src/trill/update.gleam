import board.{type Card, Card}
import board_config.{type BoardConfig, BoardConfig}
import board_config_form
import components
import confirm_modal
import context_menu
import ffi/dataview.{type Page, Page}
import ffi/neovim
import ffi/obsidian/modal
import ffi/obsidian/plugin
import ffi/obsidian/vault
import ffi/plinth_ext/element as pxelement
import ffi/plinth_ext/event as pxevent
import ffi/plinth_ext/global
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre/effect.{type Effect}
import obsidian_context.{type ObsidianContext}
import plinth/browser/element as pelement
import plinth/browser/event as pevent
import plinth/browser/window
import plinth/javascript/global as pglobal
import tempo
import trill/defs.{type Model, type Msg, Model}
import trill/internal_link

type Update =
  #(Model, Effect(Msg))

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
        dispatch(defs.UserSubmittedNewBoardForm(dynamic.from(ev)))
      })

      window.add_event_listener("user-submitted-edit-board-form", fn(ev) {
        dispatch(defs.UserSubmittedEditBoardForm(dynamic.from(ev)))
      })

      window.add_event_listener("user-clicked-delete-board-confirm", fn(_ev) {
        dispatch(defs.UserClickedDeleteBoardConfirm)
      })

      window.add_event_listener("user-clicked-delete-board-cancel", fn(_ev) {
        dispatch(defs.UserClickedDeleteBoardCancel)
      })

      ["create", "modify", "delete", "rename"]
      |> list.each(fn(event) {
        vault.on(model.obsidian_context.vault, event, fn(_file) {
          let _ =
            global.get_timer_id("file-changed-debounce")
            |> result.try(fn(id) { pglobal.clear_timeout(id) |> Ok() })

          let id =
            pglobal.set_timeout(500, fn() {
              dispatch(defs.ObsidianReportedFileChange)
            })

          global.set_global("file-changed-debounce", id)
        })
      })
    }),
  )
  |> select_board_config(board_config)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    defs.InternalLinks(inner_msg) -> {
      let #(_inner_model, effect) = internal_link.update(inner_msg)
      #(model, effect.map(effect, defs.InternalLinks))
    }

    defs.UserStartedDraggingCard(_event, card) -> {
      let assert Some(board) = model.board
      let assert Card(page) = card

      #(model, effect.none())
      |> update_board(board.start_dragging(board, page))
    }

    defs.UserStoppedDraggingCard(_event) -> {
      let assert Some(board) = model.board
      let assert Some(Card(page)) = board.dragging
      let #(board, new_status) = board.drop(board)

      #(model, effect.none())
      |> update_board(board)
      |> maybe_write_new_status(page, new_status)
    }

    defs.UserDraggedCardOverTarget(event, over_card) -> {
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

    defs.UserDraggedCardOverColumn(_event, over_column) -> {
      let assert Some(board) = model.board

      #(model, effect.none())
      |> update_board(board.drag_over_column(board, over_column))
    }

    defs.UserClickedEditInNeoVim(page) -> {
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

    defs.UserClickedArchiveAllDone -> {
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

    defs.UserSelectedBoardConfig(board_config) -> {
      #(model, effect.none())
      |> select_board_config(Some(board_config))
    }

    defs.ObsidianReadPageContents(contents) -> {
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

    defs.UserClickedBoardMenu(ev) -> {
      #(model, effect.none())
      |> show_context_menu(ev, [
        #("New board", "file-plus-2", defs.UserClickedNewBoard),
        #("Duplicate board", "copy-plus", defs.UserClickedDuplicateBoard),
        #("Edit board", "pencil", defs.UserClickedEditBoard),
        #("Delete board", "trash-2", defs.UserClickedDeleteBoard),
      ])
    }

    defs.UserClickedNewBoard -> {
      #(model, effect.none())
      |> show_board_config_form_modal(
        None,
        "user-submitted-new-board-form",
        "Create Board",
      )
    }

    defs.UserClickedDuplicateBoard -> {
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

    defs.UserClickedEditBoard -> {
      #(model, effect.none())
      |> show_board_config_form_modal(
        model.board_config,
        "user-submitted-edit-board-form",
        "Save Board",
      )
    }

    defs.UserClickedDeleteBoard -> {
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

    defs.UserSubmittedNewBoardForm(ev) -> {
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

    defs.UserSubmittedEditBoardForm(ev) -> {
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

    defs.UserClickedDeleteBoardConfirm -> {
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

    defs.UserClickedDeleteBoardCancel -> {
      #(model, effect.none())
      |> close_modal()
    }

    defs.ObsidianReportedFileChange -> {
      case model.board_config {
        Some(board_config) ->
          #(model, effect.none())
          |> select_board_config(Some(board_config))

        _ -> #(model, effect.none())
      }
    }
  }
}

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
            dispatch(defs.ObsidianReadPageContents(dict.from_list(contents)))
          })
          Nil
        })

      let board =
        board.new_board(
          group_keys: board_config.statuses,
          cards: pages,
          group_key_fn: defs.group_key_fn,
          update_group_key_fn: defs.update_group_key_fn,
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
