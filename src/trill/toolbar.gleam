import board_config.{type BoardConfig, BoardConfig}
import board_config_form
import components
import confirm_modal
import context_menu
import ffi/obsidian/modal.{type Modal}
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import icons
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element/html as h
import lustre/event
import obsidian_context.{type ObsidianContext}

pub const user_submitted_new_board_form = "user-submitted-new-board-form"

pub const user_submitted_edit_board_form = "user-submitted-edit-board-form"

pub const user_clicked_delete_board_confirm = "user-clicked-delete-board-confirm"

pub const user_clicked_delete_board_cancel = "user-clicked-delete-board-cancel"

pub type Model {
  Model(
    obs: ObsidianContext,
    board_config: BoardConfig,
    board_configs: List(BoardConfig),
  )
}

pub fn maybe_toolbar(obs: ObsidianContext, board_configs: List(BoardConfig)) {
  case list.first(board_configs) {
    Ok(board_config) -> Some(Model(obs:, board_configs:, board_config:))
    Error(Nil) -> None
  }
}

pub fn current_board_config(toolbar: Model) {
  toolbar.board_config
}

pub fn add_board_config(toolbar: Model, board_config: BoardConfig) {
  let board_configs =
    [board_config, ..toolbar.board_configs]
    |> list.sort(fn(a, b) { string.compare(a.name, b.name) })
  Model(..toolbar, board_configs:)
}

pub fn select_board_config(toolbar: Model, board_config: BoardConfig) {
  Model(..toolbar, board_config:)
}

pub fn update_current_board_config(
  toolbar: Model,
  updated_board_config: BoardConfig,
) {
  let board_configs =
    toolbar.board_configs
    |> list.map(fn(bc) {
      case bc {
        bc if bc == toolbar.board_config -> updated_board_config
        bc -> bc
      }
    })

  Model(..toolbar, board_configs:, board_config: updated_board_config)
}

pub fn delete_current_board_config(toolbar: Model) {
  let board_configs =
    list.filter(toolbar.board_configs, fn(bc) { bc != toolbar.board_config })

  case list.first(toolbar.board_configs) {
    Ok(board_config) -> Some(Model(..toolbar, board_config:, board_configs:))
    Error(Nil) -> None
  }
}

pub type Msg {
  UserSelectedBoardConfig(board_config_name: String)
  UserClickedBoardMenu(ev: Dynamic)
  UserClickedNewBoard
  UserClickedDuplicateBoard
  UserClickedEditBoard
  UserClickedDeleteBoard
  ToolbarDisplayedModal(Modal)
}

type Update =
  #(Model, Effect(Msg))

pub fn update(model: Model, msg: Msg) -> Update {
  case msg {
    UserSelectedBoardConfig(board_config_name) -> {
      let board_config =
        list.find(model.board_configs, fn(bc) { bc.name == board_config_name })

      case board_config {
        Ok(board_config) -> #(Model(..model, board_config:), effect.none())
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
        board_config.new_board_config,
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

fn show_confirm_delete_modal(update: Update) {
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

fn display_modal(modal: Modal) {
  effect.from(fn(dispatch) {
    modal.open(modal)
    dispatch(ToolbarDisplayedModal(modal))
  })
}

pub fn view(model: Model) {
  h.div([attr.class("flex justify-start mb-2 gap-2")], [
    h.select(
      [attr.class("dropdown"), event.on_input(UserSelectedBoardConfig)],
      list.map(model.board_configs, fn(board_config) {
        h.option(
          [
            attr.selected(board_config == model.board_config),
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
  ])
}
