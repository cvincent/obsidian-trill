import board.{type Card, Card}
import board_config.{type BoardConfig, BoardConfig}
import ffi/dataview.{type Page, Page}
import ffi/neovim
import ffi/obsidian/modal
import ffi/obsidian/plugin
import ffi/obsidian/vault
import ffi/plinth_ext/element as pxelement
import ffi/plinth_ext/event as pxevent
import ffi/plinth_ext/global
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre/effect.{type Effect}
import obsidian_context.{type ObsidianContext} as obs
import plinth/browser/element as pelement
import plinth/browser/event as pevent
import plinth/browser/window
import plinth/javascript/global as pglobal
import tempo
import trill/defs.{type Model, type Msg, Model}
import trill/internal_link
import trill/toolbar

type Update =
  #(Model, Effect(Msg))

pub fn init(obs: ObsidianContext) -> #(Model, Effect(Msg)) {
  let board_configs = board_config.list_from_json(obs.saved_data)
  let toolbar = toolbar.maybe_toolbar(obs, board_configs)
  let board_config = option.map(toolbar, toolbar.current_board_config)

  let model = Model(toolbar:, obs:, board: None, modal: None)

  #(
    model,
    effect.from(fn(dispatch) {
      window.add_event_listener(toolbar.user_submitted_new_board_form, fn(ev) {
        dispatch(defs.UserSubmittedNewBoardConfigForm(dynamic.from(ev)))
      })

      window.add_event_listener(toolbar.user_submitted_edit_board_form, fn(ev) {
        dispatch(defs.UserSubmittedEditBoardConfigForm(dynamic.from(ev)))
      })

      window.add_event_listener(
        toolbar.user_clicked_delete_board_confirm,
        fn(_ev) { dispatch(defs.UserClickedDeleteBoardConfigConfirm) },
      )

      window.add_event_listener(
        toolbar.user_clicked_delete_board_cancel,
        fn(_ev) { dispatch(defs.UserClickedDeleteBoardConfigCancel) },
      )

      ["create", "modify", "delete", "rename"]
      |> list.each(fn(event) {
        vault.on(model.obs.vault, event, fn(_file) {
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
  |> build_board_from_config(board_config)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    defs.InternalLinkMsg(inner_msg) -> {
      let #(_inner_model, effect) = internal_link.update(inner_msg)
      #(model, effect.map(effect, defs.InternalLinkMsg))
    }

    defs.ToolbarMsg(
      toolbar.UserSelectedBoardConfig(board_config) as toolbar_msg,
    ) -> {
      #(model, effect.none())
      |> toolbar_update(toolbar_msg)
      |> build_board_from_config(Some(board_config))
    }

    defs.ToolbarMsg(toolbar.ToolbarDisplayedModal(modal)) -> #(
      Model(..model, modal: Some(modal)),
      effect.none(),
    )

    defs.ToolbarMsg(toolbar_msg) -> {
      #(model, effect.none())
      |> toolbar_update(toolbar_msg)
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
      let assert Ok(file) = vault.get_file_by_path(model.obs.vault, page.path)

      let assert Ok(neovim) =
        decode.run(
          dynamic.from(model.obs.app),
          decode.at(
            ["plugins", "plugins", "edit-in-neovim", "neovim"],
            decode.dynamic,
          ),
        )

      neovim.open_file(model.obs.vault, neovim, file)

      #(model, effect.none())
    }

    defs.UserClickedArchiveAllDone -> {
      let assert Some(board) = model.board

      board.groups
      |> dict.get(board_config.done_status)
      |> result.unwrap([])
      |> list.each(fn(card) {
        let assert Card(page) = card
        obs.add_tag(model.obs, page.path, "archive")
        page
      })

      let board_config = option.map(model.toolbar, toolbar.current_board_config)

      #(model, effect.none())
      |> build_board_from_config(board_config)
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

    defs.UserSubmittedNewBoardConfigForm(ev) -> {
      let assert Ok(new_board_config) =
        decode.run(ev, decode.at(["detail"], board_config.from_json()))

      let toolbar =
        option.map(model.toolbar, fn(toolbar) {
          toolbar
          |> toolbar.add_board_config(new_board_config)
          |> toolbar.select_board_config(new_board_config)
        })

      #(model, effect.none())
      |> update_toolbar(toolbar)
      |> build_board_from_config(Some(new_board_config))
      |> close_modal()
      |> save_board_configs()
    }

    defs.UserSubmittedEditBoardConfigForm(ev) -> {
      let assert Ok(updated_board_config) =
        decode.run(ev, decode.at(["detail"], board_config.from_json()))

      let toolbar =
        option.map(model.toolbar, toolbar.update_current_board_config(
          _,
          updated_board_config,
        ))

      #(model, effect.none())
      |> update_toolbar(toolbar)
      |> build_board_from_config(Some(updated_board_config))
      |> save_board_configs()
      |> close_modal()
    }

    defs.UserClickedDeleteBoardConfigConfirm -> {
      let toolbar =
        option.then(model.toolbar, toolbar.delete_current_board_config(_))

      let current_board_config =
        option.map(toolbar, toolbar.current_board_config)

      #(model, effect.none())
      |> update_toolbar(toolbar)
      |> build_board_from_config(current_board_config)
      |> save_board_configs()
      |> close_modal()
    }

    // TODO: Can we have modals dismiss themselves?
    defs.UserClickedDeleteBoardConfigCancel -> {
      #(model, effect.none())
      |> close_modal()
    }

    defs.ObsidianReportedFileChange -> {
      case model.toolbar {
        Some(toolbar.Model(board_config:, ..)) ->
          #(model, effect.none())
          |> build_board_from_config(Some(board_config))

        _ -> #(model, effect.none())
      }
    }
  }
}

fn update_board(update: Update, board) -> Update {
  let #(model, effects) = update
  #(Model(..model, board: Some(board)), effects)
}

fn toolbar_update(update: Update, toolbar_msg: toolbar.Msg) {
  let #(model, effects) = update

  let toolbar_update = option.map(model.toolbar, toolbar.update(_, toolbar_msg))
  let toolbar =
    option.map(toolbar_update, fn(toolbar_update) { toolbar_update.0 })

  let effect =
    toolbar_update
    |> option.map(fn(toolbar_update) { toolbar_update.1 })
    |> option.unwrap(effect.none())
    |> effect.map(defs.ToolbarMsg)

  #(Model(..model, toolbar:), effect.batch([effect, effects]))
}

fn update_toolbar(update: Update, toolbar: Option(toolbar.Model)) {
  #(Model(..update.0, toolbar: toolbar), update.1)
}

fn build_board_from_config(
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
            vault.get_file_by_path(model.obs.vault, page.path)
            |> result.try(fn(file) {
              vault.cached_read(model.obs.vault, file)
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

  #(Model(..model, board: Some(board)), effect.batch([effect, effects]))
}

fn close_modal(update: Update) -> Update {
  let #(model, effects) = update

  let effect = case model.modal {
    Some(modal) -> effect.from(fn(_) { modal.close(modal) })
    None -> effect.none()
  }

  #(Model(..model, modal: None), effect.batch([effect, effects]))
}

fn save_board_configs(update: Update) -> Update {
  let #(model, effects) = update

  let effect =
    option.map(model.toolbar, fn(toolbar) {
      use _ <- effect.from
      let save_data = board_config.list_to_json(toolbar.board_configs)
      plugin.save_data(model.obs.plugin, save_data)
    })
    |> option.unwrap(effect.none())

  #(model, effect.batch([effect, effects]))
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

        obs.set_front_matter(model.obs, page.path, "status", new_status)

        case new_status {
          Some(done) if done == board_config.done_status ->
            obs.set_front_matter(
              model.obs,
              page.path,
              "done",
              Some(tempo.format_local(tempo.ISO8601Seconds)),
            )
          _ -> {
            obs.set_front_matter(model.obs, page.path, "done", None)
          }
        }
      })
  }

  #(model, effect.batch([effect, effects]))
}
