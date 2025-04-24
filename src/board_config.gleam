import ffi/plinth_ext/crypto
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/result

pub type BoardConfig {
  BoardConfig(id: String, name: String, query: String, statuses: List(String))
}

pub const null_status = "none"

pub const done_status = "done"

pub const statuses = [
  null_status,
  "inbox",
  "ideas",
  "needs-research",
  "ready",
  "in-progress",
  done_status,
]

// TODO: Make these more consistent; it should be clear when we're working with
// strings vs dynamics

pub fn new() {
  BoardConfig(id: crypto.random_uuid(), name: "", query: "", statuses:)
}

pub fn from_json() {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use query <- decode.field("query", decode.string)
  use statuses <- decode.field("statuses", decode.list(decode.string))
  decode.success(BoardConfig(id:, name:, query:, statuses: statuses))
}

pub fn list_from_json(data: Option(String)) {
  let data = option.unwrap(data, "{\"board_configs\": []}")

  let data_decoder = {
    use board_configs <- decode.field("board_configs", decode.list(from_json()))
    decode.success(board_configs)
  }

  data
  |> json.parse(data_decoder)
  |> result.unwrap([])
}

pub fn to_json(board_config: BoardConfig) {
  json.object([
    #("id", json.string(board_config.id)),
    #("name", json.string(board_config.name)),
    #("query", json.string(board_config.query)),
    #("statuses", json.array(board_config.statuses, json.string)),
  ])
}

pub fn list_to_json(board_configs: List(BoardConfig)) {
  json.object([#("board_configs", json.array(board_configs, to_json))])
}

pub fn update(
  board_config: BoardConfig,
  field: String,
  value: String,
) -> BoardConfig {
  case field {
    "name" -> BoardConfig(..board_config, name: value)
    "query" -> BoardConfig(..board_config, query: value)
    _ -> board_config
  }
}
