import lustre.{type App}
import obsidian_context.{type ObsidianContext}
import trill/defs.{type Model, type Msg, Model}
import trill/update
import trill/view

pub const view_name = defs.view_name

pub fn app() -> App(ObsidianContext, Model, Msg) {
  lustre.application(update.init, update.update, view.view)
}
