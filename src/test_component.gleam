import gleam/dict
import gleam/int
import lustre.{type App}
import lustre/effect.{type Effect}
import lustre/element/html as h
import lustre/event

pub type Model {
  Model(count: Int)
}

pub type Msg {
  Inc
}

pub fn register(callback) {
  callback("test-component", fn(name) { lustre.register(component(), name) })
}

pub fn component() -> App(Nil, Model, Msg) {
  lustre.component(init, update, view, dict.from_list([]))
}

pub fn init(_data) -> #(Model, Effect(Msg)) {
  #(Model(0), effect.none())
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Inc -> #(Model(count: model.count + 2), effect.none())
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
