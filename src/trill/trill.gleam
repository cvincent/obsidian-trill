import board_config
import board_config_form
import components
import ffi/obsidian/modal.{type Modal}
import ffi/obsidian/plugin
import ffi/obsidian/vault
import ffi/plinth_ext/global
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre.{type App}
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import obsidian_context.{type ObsidianContext}
import plinth/browser/window
import plinth/javascript/global as pglobal
import trill/board_view
import trill/toolbar
import util

pub const view_name = "trill"

pub fn app() -> App(ObsidianContext, Model, Msg) {
  lustre.application(init, update, view)
}

pub type Model {
  Model(
    obs: ObsidianContext,
    toolbar: Option(toolbar.Model),
    board_view: Option(board_view.Model),
    modal: Option(Modal),
  )
}

pub type Msg {
  ToolbarMsg(toolbar.Msg)
  BoardViewMsg(board_view.Msg)

  UserSubmittedNewBoardConfigForm(event: Dynamic)
  UserSubmittedEditBoardConfigForm(event: Dynamic)
  UserClickedDeleteBoardConfigCancel
  UserClickedDeleteBoardConfigConfirm

  ObsidianReportedFileChange
}

type Update =
  #(Model, Effect(Msg))

pub fn init(obs: ObsidianContext) -> #(Model, Effect(Msg)) {
  let board_configs = board_config.list_from_json(obs.saved_data)
  let toolbar = toolbar.maybe_toolbar(obs, board_configs)

  let board_view =
    option.map(toolbar, fn(toolbar) {
      board_view.new(obs, toolbar.board_config)
    })

  let model = Model(toolbar:, obs:, board_view:, modal: None)

  #(
    model,
    effect.from(fn(dispatch) {
      window.add_event_listener(toolbar.user_submitted_new_board_form, fn(ev) {
        dispatch(UserSubmittedNewBoardConfigForm(dynamic.from(ev)))
      })

      window.add_event_listener(toolbar.user_submitted_edit_board_form, fn(ev) {
        dispatch(UserSubmittedEditBoardConfigForm(dynamic.from(ev)))
      })

      window.add_event_listener(
        toolbar.user_clicked_delete_board_confirm,
        fn(_ev) { dispatch(UserClickedDeleteBoardConfigConfirm) },
      )

      window.add_event_listener(
        toolbar.user_clicked_delete_board_cancel,
        fn(_ev) { dispatch(UserClickedDeleteBoardConfigCancel) },
      )

      ["create", "modify", "delete", "rename"]
      |> list.each(fn(event) {
        vault.on(model.obs.vault, event, fn(_file) {
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
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ToolbarMsg(toolbar.UserSelectedBoardConfig(_board_config) as toolbar_msg) ->
      #(model, effect.none())
      |> toolbar_update(toolbar_msg)
      |> update_board_view_board_config()

    ToolbarMsg(toolbar.ToolbarDisplayedModal(modal) as toolbar_msg) ->
      #(Model(..model, modal: Some(modal)), effect.none())
      |> toolbar_update(toolbar_msg)

    ToolbarMsg(toolbar_msg) ->
      #(model, effect.none())
      |> toolbar_update(toolbar_msg)

    BoardViewMsg(board_view_msg) ->
      #(model, effect.none())
      |> board_view_update(board_view_msg)

    UserSubmittedNewBoardConfigForm(ev) -> {
      use new_board_config <- util.result_guard(
        decode.run(ev, decode.at(["detail"], board_config.from_json())),
        #(model, effect.none()),
      )

      let toolbar =
        option.map(model.toolbar, fn(toolbar) {
          toolbar
          |> toolbar.add_board_config(new_board_config)
          |> toolbar.select_board_config(new_board_config)
        })

      #(model, effect.none())
      |> update_toolbar(toolbar)
      |> update_board_view_board_config()
      |> save_board_configs()
      |> close_modal()
    }

    UserSubmittedEditBoardConfigForm(ev) -> {
      use updated_board_config <- util.result_guard(
        decode.run(ev, decode.at(["detail"], board_config.from_json())),
        #(model, effect.none()),
      )

      let toolbar =
        option.map(model.toolbar, toolbar.update_current_board_config(
          _,
          updated_board_config,
        ))

      #(model, effect.none())
      |> update_toolbar(toolbar)
      |> update_board_view_board_config()
      |> save_board_configs()
      |> close_modal()
    }

    UserClickedDeleteBoardConfigConfirm -> {
      let toolbar =
        option.then(model.toolbar, toolbar.delete_current_board_config(_))

      #(model, effect.none())
      |> update_toolbar(toolbar)
      |> update_board_view_board_config()
      |> save_board_configs()
      |> close_modal()
    }

    // TODO: Generic event(s) for closing whatever modal happens to be open
    UserClickedDeleteBoardConfigCancel -> {
      #(model, effect.none())
      |> close_modal()
    }

    ObsidianReportedFileChange -> {
      #(model, effect.none())
      |> update_board_view_board_config()
    }
  }
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
    |> effect.map(ToolbarMsg)

  #(Model(..model, toolbar:), effect.batch([effect, effects]))
}

fn update_toolbar(update: Update, toolbar: Option(toolbar.Model)) {
  #(Model(..update.0, toolbar:), update.1)
}

fn board_view_update(update: Update, board_view_msg: board_view.Msg) {
  let #(model, effects) = update

  let board_view_update =
    option.map(model.board_view, board_view.update(_, board_view_msg))
  let board_view =
    option.map(board_view_update, fn(board_view_update) { board_view_update.0 })

  let effect =
    board_view_update
    |> option.map(fn(board_view_update) { board_view_update.1 })
    |> option.unwrap(effect.none())
    |> effect.map(BoardViewMsg)

  #(Model(..model, board_view:), effect.batch([effect, effects]))
}

pub fn update_board_view_board_config(update: Update) {
  let #(model, effects) = update

  let board_view = {
    use board_view <- option.then(model.board_view)
    use toolbar <- option.map(model.toolbar)
    board_view.update_board_config(board_view, toolbar.board_config)
  }

  #(Model(..model, board_view:), effects)
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

fn close_modal(update: Update) -> Update {
  let #(model, effects) = update

  let effect = case model.modal {
    Some(modal) -> effect.from(fn(_) { modal.close(modal) })
    None -> effect.none()
  }

  #(Model(..model, modal: None), effect.batch([effect, effects]))
}

pub fn view(model: Model) -> Element(Msg) {
  case model.toolbar {
    Some(_toolbar) -> board_view(model)
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
  let toolbar =
    model.toolbar
    |> option.map(toolbar.view)
    |> option.unwrap(element.none())
    |> element.map(ToolbarMsg)

  let board_view =
    model.board_view
    |> option.map(board_view.view)
    |> option.unwrap(element.none())
    |> element.map(BoardViewMsg)

  h.div([attr.class("h-full")], [toolbar, board_view])
}
