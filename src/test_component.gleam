import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import lustre.{type App}
import lustre/effect.{type Effect}
import lustre/element/html as h
import lustre/event
import plinth/javascript/console

pub type Model {
  Model(count: Int, parent_msg: Option(String))
}

pub type Msg {
  Inc
  ParentSetParentMsg(msg: String)
}

pub fn register(callback) {
  callback("test-component", fn(name) { lustre.register(component(), name) })
}

pub fn component() -> App(Nil, Model, Msg) {
  lustre.component(
    init,
    update,
    view,
    dict.from_list([
      #("parent-msg", fn(dyn) {
        let assert Ok(msg) = decode.run(dyn, decode.string)
        console.log("setting parent_msg: " <> msg)
        Ok(ParentSetParentMsg(msg))
      }),
    ]),
  )
}

pub fn init(_data) -> #(Model, Effect(Msg)) {
  #(Model(0, None), effect.none())
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Inc -> {
      let effect = case model.parent_msg {
        None -> effect.none()
        Some(parent_msg) ->
          event.emit(
            parent_msg,
            json.object([#("encapsulated", json.string("stuff"))]),
          )
      }

      #(Model(..model, count: model.count + 1), effect)
    }
    ParentSetParentMsg(msg) -> #(
      Model(..model, parent_msg: Some(msg)),
      effect.none(),
    )
  }
}

pub fn view(model: Model) {
  h.div([], [
    h.div([], [
      h.text(int.to_string(model.count)),
      h.button([event.on_click(Inc)], [h.text("inc")]),
    ]),
  ])
}
