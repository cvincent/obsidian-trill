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
import util

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
  let no_change = #(model, effect.none())

  case msg {
    ParentSetAttr("prompt", value) -> {
      use prompt <- util.result_guard(
        decode.run(value, decode.string),
        no_change,
      )
      #(Model(..model, prompt:), effect.none())
    }

    ParentSetAttr("confirm", value) -> {
      use confirm <- util.result_guard(
        decode.run(value, decode.string),
        no_change,
      )
      #(Model(..model, confirm:), effect.none())
    }

    ParentSetAttr("emit-confirm", value) -> {
      use emit_confirm <- util.result_guard(
        decode.run(value, decode.optional(decode.string)),
        no_change,
      )
      #(Model(..model, emit_confirm:), effect.none())
    }

    ParentSetAttr("emit-cancel", value) -> {
      use emit_cancel <- util.result_guard(
        decode.run(value, decode.optional(decode.string)),
        no_change,
      )
      #(Model(..model, emit_cancel:), effect.none())
    }

    ParentSetAttr(_, _) -> no_change

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
