import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event

const attrs = ["prompt", "confirm", "emit-confirm", "emit-cancel"]

const element_name = "confirm-modal"

pub fn register(callback) {
  callback(element_name, fn(name) { lustre.register(component(), name) })
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

pub fn element(
  name_func: fn(String) -> String,
  prompt: String,
  confirm: String,
  emit_confirm: String,
  emit_cancel: String,
) {
  element.element(
    name_func(element_name),
    [
      attr.attribute("prompt", prompt),
      attr.attribute("confirm", confirm),
      attr.attribute("emit-confirm", emit_confirm),
      attr.attribute("emit-cancel", emit_cancel),
    ],
    [],
  )
}

pub type Model {
  Model(
    prompt: String,
    confirm: String,
    emit_confirm: Option(String),
    emit_cancel: Option(String),
  )
}

pub type Msg {
  ParentSetAttr(attr: String, value: Dynamic)
  UserConfirmed
  UserCancelled
}

fn init(_) {
  #(
    Model(
      prompt: "Are you sure?",
      confirm: "Confirm",
      emit_confirm: None,
      emit_cancel: None,
    ),
    effect.none(),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ParentSetAttr("prompt", value) -> {
      let assert Ok(prompt) = decode.run(value, decode.string)
      #(Model(..model, prompt:), effect.none())
    }

    ParentSetAttr("confirm", value) -> {
      let assert Ok(confirm) = decode.run(value, decode.string)
      #(Model(..model, confirm:), effect.none())
    }

    ParentSetAttr("emit-confirm", value) -> {
      let assert Ok(emit_confirm) =
        decode.run(value, decode.optional(decode.string))
      #(Model(..model, emit_confirm:), effect.none())
    }

    ParentSetAttr("emit-cancel", value) -> {
      let assert Ok(emit_cancel) =
        decode.run(value, decode.optional(decode.string))
      #(Model(..model, emit_cancel:), effect.none())
    }

    ParentSetAttr(_, _) -> panic

    UserConfirmed -> {
      case model.emit_confirm {
        None -> #(model, effect.none())
        Some(emit) -> #(model, event.emit(emit, json.null()))
      }
    }

    UserCancelled -> {
      case model.emit_cancel {
        None -> #(model, effect.none())
        Some(emit) -> #(model, event.emit(emit, json.null()))
      }
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  h.div([attr.class("font-(family-name:--font-text)")], [
    h.p([], [h.text(model.prompt)]),
    h.div([attr.class("flex justify-end gap-2")], [
      h.button([event.on_click(UserCancelled)], [h.text("Cancel")]),
      h.button([attr.class("mod-destructive"), event.on_click(UserConfirmed)], [
        h.text(model.confirm),
      ]),
    ]),
  ])
}
