import board_config.{type BoardConfig}
import board_config_form
import components
import ffi/obsidian/modal.{type Modal}
import ffi/obsidian/plugin
import ffi/obsidian/vault
import ffi/plinth_ext/global
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
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

pub const file_changed_debounce = "file-changed-debounce"

pub const save_filter_debounce = "save-filter-debounce"

pub fn app() -> App(ObsidianContext, Model, Msg) {
  lustre.application(init, update, view)
}

type TrillSave {
  TrillSave(board_configs: List(BoardConfig))
}

fn encode_trill_save(trill_save: TrillSave) -> json.Json {
  json.object([
    #(
      "board_configs",
      json.array(trill_save.board_configs, board_config.encode_board_config),
    ),
  ])
}

fn trill_save_decoder() -> decode.Decoder(TrillSave) {
  use board_configs <- decode.field(
    "board_configs",
    decode.list(board_config.board_config_decoder()),
  )
  decode.success(TrillSave(board_configs:))
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
  FilterSaveDebounced
}

type Update =
  #(Model, Effect(Msg))

pub fn init(obs: ObsidianContext) -> Update {
  let board_configs =
    obs.saved_data
    |> option.unwrap("{\"board_configs\": []}")
    |> json.parse(trill_save_decoder())
    |> result.unwrap(TrillSave([]))
    |> util.then(fn(trill_save) { trill_save.board_configs })

  let toolbar = toolbar.maybe_toolbar(obs, board_configs)

  let #(board_view, board_view_effect) =
    option.map(toolbar, fn(toolbar) {
      let #(board_view, effect) = board_view.new(obs, toolbar.board_config)
      #(Some(board_view), effect.map(effect, BoardViewMsg))
    })
    |> option.unwrap(#(None, effect.none()))

  let model = Model(toolbar:, obs:, board_view:, modal: None)

  #(
    model,
    effect.batch([
      board_view_effect,
      effect.from(fn(dispatch) {
        window.add_event_listener(toolbar.user_submitted_new_board_form, fn(ev) {
          dispatch(UserSubmittedNewBoardConfigForm(dynamic.from(ev)))
        })

        window.add_event_listener(
          toolbar.user_submitted_edit_board_form,
          fn(ev) {
            dispatch(UserSubmittedEditBoardConfigForm(dynamic.from(ev)))
          },
        )

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
              global.get_timer_id(file_changed_debounce)
              |> result.try(fn(id) { pglobal.clear_timeout(id) |> Ok() })

            let id =
              pglobal.set_timeout(500, fn() {
                dispatch(ObsidianReportedFileChange)
              })

            global.set_global(file_changed_debounce, id)
          })
        })
      }),
    ]),
  )
}

pub fn update(model: Model, msg: Msg) -> Update {
  case msg {
    ToolbarMsg(toolbar.ToolbarDisplayedModal(modal) as toolbar_msg) ->
      #(Model(..model, modal: Some(modal)), effect.none())
      |> handle_toolbar_msg(toolbar_msg)

    ToolbarMsg(toolbar_msg) ->
      #(model, effect.none())
      |> handle_toolbar_msg(toolbar_msg)

    BoardViewMsg(board_view_msg) ->
      #(model, effect.none())
      |> handle_board_view_msg(board_view_msg)

    UserSubmittedNewBoardConfigForm(ev) -> {
      use new_board_config <- util.result_guard(
        decode.run(
          ev,
          decode.at(["detail"], board_config.board_config_decoder()),
        ),
        #(model, effect.none()),
      )

      let toolbar =
        option.map(model.toolbar, fn(toolbar) {
          toolbar
          |> toolbar.add_board_config(new_board_config)
          |> toolbar.set_current_board_config(new_board_config)
        })

      #(model, effect.none())
      |> update_toolbar(toolbar)
      |> sync_board_view_board_config_from_toolbar(False)
      |> save_board_configs()
      |> close_modal()
    }

    UserSubmittedEditBoardConfigForm(ev) -> {
      use updated_board_config <- util.result_guard(
        decode.run(
          ev,
          decode.at(["detail"], board_config.board_config_decoder()),
        ),
        #(model, effect.none()),
      )

      let toolbar =
        option.map(model.toolbar, toolbar.set_current_board_config(
          _,
          updated_board_config,
        ))

      #(model, effect.none())
      |> update_toolbar(toolbar)
      |> sync_board_view_board_config_from_toolbar(False)
      |> save_board_configs()
      |> close_modal()
    }

    UserClickedDeleteBoardConfigConfirm -> {
      let toolbar =
        option.then(model.toolbar, toolbar.delete_current_board_config)

      #(model, effect.none())
      |> update_toolbar(toolbar)
      |> sync_board_view_board_config_from_toolbar(False)
      |> save_board_configs()
      |> close_modal()
    }

    // TODO: Generic event(s) for closing whatever modal happens to be open
    UserClickedDeleteBoardConfigCancel -> {
      #(model, effect.none())
      |> close_modal()
    }

    ObsidianReportedFileChange ->
      #(model, effect.none())
      |> sync_board_view_board_config_from_toolbar(True)

    FilterSaveDebounced ->
      #(model, effect.none())
      |> save_board_configs()
  }
}

fn handle_toolbar_msg(update: Update, toolbar_msg: toolbar.Msg) -> Update {
  let #(model, effects) = update

  {
    use toolbar <- option.map(model.toolbar)
    use board_view <- option.map(model.board_view)

    let #(toolbar, effect) = toolbar.update(toolbar, toolbar_msg)
    let toolbar_board_config = toolbar.board_config
    let toolbar = Some(toolbar)
    let effect = effect.map(effect, ToolbarMsg)

    #(model, effect.batch([effect, effects]))
    |> update_toolbar(toolbar)
    |> util.pipe_if(toolbar_board_config != board_view.board_config, fn(update) {
      #(update.0, effect.batch([debounce_filter_save(), update.1]))
      |> sync_board_view_board_config_from_toolbar(False)
    })
  }
  |> option.flatten()
  |> option.unwrap(update)
}

fn debounce_filter_save() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let _ =
      global.get_timer_id(save_filter_debounce)
      |> result.try(fn(id) { pglobal.clear_timeout(id) |> Ok() })

    let id = pglobal.set_timeout(1000, fn() { dispatch(FilterSaveDebounced) })

    global.set_global(save_filter_debounce, id)
  })
}

fn handle_board_view_msg(
  update: Update,
  board_view_msg: board_view.Msg,
) -> Update {
  let #(model, effects) = update

  {
    use board_view <- option.map(model.board_view)

    let #(board_view, effect) = board_view.update(board_view, board_view_msg)
    let board_view = Some(board_view)
    let effect = effect.map(effect, BoardViewMsg)

    #(Model(..model, board_view:), effect.batch([effect, effects]))
  }
  |> option.unwrap(update)
}

fn update_toolbar(update: Update, toolbar: Option(toolbar.Model)) -> Update {
  #(Model(..update.0, toolbar:), update.1)
}

pub fn sync_board_view_board_config_from_toolbar(
  update: Update,
  force_refresh: Bool,
) -> Update {
  let #(model, effects) = update

  {
    use board_view <- option.then(model.board_view)
    use toolbar <- option.map(model.toolbar)

    let #(board_view, effect) =
      board_view.update_board_config(
        board_view,
        toolbar.board_config,
        force_refresh,
      )

    #(
      Model(..model, board_view: Some(board_view)),
      effect.batch([effect.map(effect, BoardViewMsg), effects]),
    )
  }
  |> option.unwrap(#(model, effects))
}

fn save_board_configs(update: Update) -> Update {
  let #(model, effects) = update

  let effect =
    option.map(model.toolbar, fn(toolbar) {
      use _ <- effect.from
      let save_data = encode_trill_save(TrillSave(toolbar.board_configs))
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

  h.div([attr.class("h-full absolute top-10 right-0 bottom-0 left-0")], [
    h.div([attr.class("px-4")], [toolbar]),
    h.div([attr.class("w-full h-full overflow-x-auto")], [board_view]),
  ])
}
