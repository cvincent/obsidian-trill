import board_config_form
import confirm_modal
import ffi/plinth_ext/global
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import gleam/time/timestamp

const namespace = "trill"

const components = [board_config_form.register, confirm_modal.register]

const timestamp_key = "components-timestamp"

pub fn setup() {
  set_timestamp()

  components
  |> list.each(fn(component_fn) {
    component_fn(fn(base_name, callback) { callback(name(base_name)) })
  })
}

pub fn name(base_name: String) -> String {
  [namespace, base_name, ensure_timestamp()]
  |> string.join("-")
}

fn ensure_timestamp() {
  case global.get_string(timestamp_key) {
    Ok(timestamp) -> timestamp
    Error(_) -> set_timestamp()
  }
}

fn set_timestamp() {
  let timestamp =
    timestamp.system_time()
    |> timestamp.to_unix_seconds()
    |> float.truncate()
    |> int.to_string()

  global.set_global(timestamp_key, timestamp)

  timestamp
}
