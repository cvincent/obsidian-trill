import ffi/dataview.{type Page, Page}
import ffi/obsidian/workspace
import gleam/dynamic.{type Dynamic}
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event
import obsidian_context.{type ObsidianContext}

pub type Model {
  Model(obsidian_context: ObsidianContext, page: Page, view_name: String)
}

pub type Msg {
  UserClicked(Model)
  UserHovered(Model, ev: Dynamic)
}

pub fn update(msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserClicked(model) -> #(
      model,
      effect.from(fn(_) {
        workspace.open_link_text(
          model.obsidian_context.workspace,
          model.page.path,
          "tab",
        )
      }),
    )

    UserHovered(model, ev) -> #(
      model,
      effect.from(fn(_) {
        workspace.trigger_hover_link(
          model.obsidian_context.workspace,
          ev,
          model.view_name,
          model.page.path,
        )
      }),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  h.a(
    [
      attr.class("internal-link"),
      attr.href(model.page.path),
      event.on_click(UserClicked(model)),
      event.on("mouseover", fn(ev) { Ok(UserHovered(model, ev)) }),
    ],
    [h.text(model.page.title)],
  )
}
