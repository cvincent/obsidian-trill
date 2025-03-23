import board_config.{type BoardConfig, BoardConfig}
import ffi/console
import ffi/dataview
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event

const attrs = ["emit-submit", "submit-label"]

pub fn register(callback) {
  callback("board-config-form", fn(name) { lustre.register(component(), name) })
}

fn component() {
  lustre.component(init, update, view, on_attribute_change())
}

fn on_attribute_change() {
  let a =
    attrs
    |> list.map(fn(attr) {
      #(attr, fn(value) { Ok(ParentSetAttr(attr, value)) })
    })
    |> dict.from_list()
  a
}

pub type Model {
  Model(
    board_config: BoardConfig,
    on_submit: Option(String),
    submit_label: String,
  )
}

pub type Msg {
  ParentSetAttr(attr: String, value: Dynamic)
  UserUpdatedField(field: String, value: String)
  UserSubmittedForm
}

fn init(_) {
  #(
    Model(
      board_config: board_config.new_board_config,
      on_submit: None,
      submit_label: "Save",
    ),
    effect.none(),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ParentSetAttr("emit-submit", value) -> {
      let assert Ok(on_submit) =
        decode.run(value, decode.optional(decode.string))
      #(Model(..model, on_submit:), effect.none())
    }

    ParentSetAttr("submit-label", value) -> {
      let assert Ok(submit_label) = decode.run(value, decode.string)
      #(Model(..model, submit_label:), effect.none())
    }

    UserUpdatedField(field, name) -> #(
      Model(
        ..model,
        board_config: board_config.update(model.board_config, field, name),
      ),
      effect.none(),
    )

    UserSubmittedForm -> {
      case model.on_submit {
        None -> #(model, effect.none())
        Some(event_name) -> {
          #(
            model,
            event.emit(event_name, board_config.to_json(model.board_config)),
          )
        }
      }
    }

    msg -> {
      console.log(msg)
      panic
    }
  }
}

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

fn view(model: Model) -> Element(Msg) {
  let heading = case model.board_config.name {
    "" -> "Create a New Board"
    name -> name
  }

  let errors = validate_board_config(model.board_config)

  let enabled = case errors |> dict.values() |> result.all() {
    Error(_) -> attr.disabled(True)
    _ -> attr.none()
  }

  h.div(
    [
      attr.class(
        "font-(family-name:--font-text) flex h-full items-center justify-center",
      ),
    ],
    [
      h.div([attr.class("w-2/3 max-w-2xl")], [
        h.h1([attr.class("text-center")], [h.text(heading)]),
        text_field(
          "Board name",
          None,
          model.board_config.name,
          dict.get(errors, "name"),
          UserUpdatedField("name", _),
        ),
        text_field(
          "Query",
          Some(
            "This Dataview query will be used to select what notes to display as cards.",
          ),
          model.board_config.query,
          dict.get(errors, "query"),
          UserUpdatedField("query", _),
        ),
        h.div([attr.class("flex justify-end mt-4")], [
          h.button([enabled, event.on_click(UserSubmittedForm)], [
            h.text(model.submit_label),
          ]),
        ]),
      ]),
    ],
  )
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
