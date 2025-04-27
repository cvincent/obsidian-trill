import board_config.{type BoardConfig, BoardConfig}
import board_config_form
import card_filter
import components
import confirm_modal
import context_menu
import ffi/dataview
import ffi/obsidian/modal.{type Modal}
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import icons
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event
import obsidian_context.{type ObsidianContext}
import trill/columns_drawer
import trill/filter_drawer

pub const user_submitted_new_board_form = "user-submitted-new-board-form"

pub const user_submitted_edit_board_form = "user-submitted-edit-board-form"

pub const user_clicked_delete_board_confirm = "user-clicked-delete-board-confirm"

pub const user_clicked_delete_board_cancel = "user-clicked-delete-board-cancel"

pub type Model {
  Model(
    obs: ObsidianContext,
    board_config: BoardConfig,
    board_configs: List(BoardConfig),
    drawer: Drawer,
    board_tags: List(String),
  )
}

pub type Drawer {
  NoDrawer
  ColumnsDrawer
  FilterDrawer
}

pub fn maybe_toolbar(
  obs: ObsidianContext,
  board_configs: List(BoardConfig),
) -> Option(Model) {
  case list.first(board_configs) {
    Ok(board_config) ->
      Some(Model(
        obs:,
        board_configs:,
        board_config:,
        drawer: NoDrawer,
        board_tags: tags_for_query(board_config.query),
      ))
    Error(Nil) -> None
  }
}

pub fn add_board_config(toolbar: Model, board_config: BoardConfig) -> Model {
  let board_configs =
    [board_config, ..toolbar.board_configs]
    |> list.sort(fn(a, b) { string.compare(a.name, b.name) })
  Model(..toolbar, board_configs:)
}

pub fn set_current_board_config(
  toolbar: Model,
  board_config: BoardConfig,
) -> Model {
  let board_configs =
    toolbar.board_configs
    |> list.map(fn(bc) {
      case bc {
        bc if bc.id == board_config.id -> board_config
        bc -> bc
      }
    })

  Model(
    ..toolbar,
    board_configs:,
    board_config: board_config,
    board_tags: tags_for_query(board_config.query),
  )
}

pub fn delete_current_board_config(toolbar: Model) -> Option(Model) {
  let board_configs =
    list.filter(toolbar.board_configs, fn(bc) { bc != toolbar.board_config })

  case list.first(toolbar.board_configs) {
    Ok(board_config) ->
      Some(
        Model(..toolbar, board_configs:)
        |> set_current_board_config(board_config),
      )
    Error(Nil) -> None
  }
}

fn tags_for_query(query: String) -> List(String) {
  dataview.pages(query)
  |> list.flat_map(fn(p) { p.tags })
  |> list.unique()
}

pub type Msg {
  UserSelectedBoardConfig(id: String)
  UserClickedBoardMenu(ev: Dynamic)
  UserClickedNewBoard
  UserClickedDuplicateBoard
  UserClickedEditBoard
  UserClickedDeleteBoard
  ToolbarDisplayedModal(Modal)

  UserClickedToggleFilterDrawer(ev: Dynamic)
  UserClickedToggleColumnsDrawer(ev: Dynamic)
  FilterDrawerMsg(filter_drawer.Msg)
  ColumnsDrawerMsg(columns_drawer.Msg)
}

type Update =
  #(Model, Effect(Msg))

pub fn update(model: Model, msg: Msg) -> Update {
  case msg {
    UserSelectedBoardConfig(id) -> {
      let board_config = list.find(model.board_configs, fn(bc) { bc.id == id })

      case board_config {
        Ok(board_config) -> #(
          set_current_board_config(model, board_config),
          effect.none(),
        )
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
        board_config.new(),
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

    UserClickedToggleFilterDrawer(_) -> #(
      Model(..model, drawer: case model.drawer {
        FilterDrawer -> NoDrawer
        _ -> FilterDrawer
      }),
      effect.none(),
    )

    FilterDrawerMsg(filter_drawer_msg) -> {
      let #(filter_drawer, effect) =
        filter_drawer.update(
          filter_drawer.Model(
            board_tags: model.board_tags,
            filter: model.board_config.filter,
          ),
          filter_drawer_msg,
        )
      let effect = effect.map(effect, FilterDrawerMsg)

      #(
        set_current_board_config(
          model,
          BoardConfig(..model.board_config, filter: filter_drawer.filter),
        ),
        effect,
      )
    }

    UserClickedToggleColumnsDrawer(_) -> #(
      Model(..model, drawer: case model.drawer {
        ColumnsDrawer -> NoDrawer
        _ -> ColumnsDrawer
      }),
      effect.none(),
    )

    ColumnsDrawerMsg(columns_drawer_msg) -> {
      let #(columns_drawer, effect) =
        columns_drawer.update(
          columns_drawer.Model(columns: model.board_config.columns),
          columns_drawer_msg,
        )
      let effect = effect.map(effect, ColumnsDrawerMsg)

      #(
        set_current_board_config(
          model,
          BoardConfig(..model.board_config, columns: columns_drawer.columns),
        ),
        effect,
      )
    }
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

fn show_confirm_delete_modal(update: Update) -> Update {
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

fn display_modal(modal: Modal) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    modal.open(modal)
    dispatch(ToolbarDisplayedModal(modal))
  })
}

pub fn view(model: Model) -> Element(Msg) {
  h.div([], [
    h.div([attr.class("flex justify-between mb-4 gap-2")], [
      toolbar_left(model),
      toolbar_right(model),
    ]),
    drawer(model),
  ])
}

fn toolbar_left(model: Model) -> Element(Msg) {
  h.div([attr.class("flex justify-start gap-2")], [
    h.select(
      [attr.class("dropdown"), event.on_input(UserSelectedBoardConfig)],
      list.map(model.board_configs, fn(board_config) {
        h.option(
          [
            attr.selected(board_config.id == model.board_config.id),
            attr.value(board_config.id),
          ],
          board_config.name,
        )
      }),
    ),
    toolbar_button("ellipsis-vertical", False, False, UserClickedBoardMenu),
  ])
}

fn toolbar_right(model: Model) -> Element(Msg) {
  h.div([attr.class("flex justify-end gap-2")], [
    toolbar_button(
      "kanban",
      model.drawer == ColumnsDrawer,
      False,
      UserClickedToggleColumnsDrawer,
    ),
    toolbar_button(
      "funnel",
      model.drawer == FilterDrawer,
      card_filter.any(model.board_config.filter),
      UserClickedToggleFilterDrawer,
    ),
  ])
}

fn toolbar_button(
  icon: String,
  drawer_open: Bool,
  active: Bool,
  msg_constructor: fn(Dynamic) -> a,
) -> Element(a) {
  let class =
    "clickable-icon [--icon-size:var(--icon-xs)] [--icon-stroke:var(--icon-xs-stroke-width)]"

  h.div(
    [
      attr.classes([
        #(class, True),
        #("[--icon-color:var(--color-orange)]", active),
        #("[--icon-color:var(--color-base-100)]", drawer_open),
      ]),
      event.on("click", fn(ev) { Ok(msg_constructor(ev)) }),
    ],
    [icons.icon(icon)],
  )
}

fn drawer(model: Model) -> Element(Msg) {
  case model.drawer {
    NoDrawer -> element.none()

    FilterDrawer ->
      filter_drawer.view(filter_drawer.Model(
        board_tags: model.board_tags,
        filter: model.board_config.filter,
      ))
      |> element.map(FilterDrawerMsg)

    ColumnsDrawer ->
      columns_drawer.view(columns_drawer.Model(
        columns: model.board_config.columns,
      ))
      |> element.map(ColumnsDrawerMsg)
  }
}
