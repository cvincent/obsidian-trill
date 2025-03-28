import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/result

pub type BoardConfig {
  BoardConfig(name: String, query: String, statuses: List(String))
}

pub const null_status = "none"

pub const statuses = [
  null_status,
  "inbox",
  "ideas",
  "needs-research",
  "ready",
  "in-progress",
  "done",
]

pub const new_board_config = BoardConfig("", "", statuses)

// TODO: Make these more consistent; it should be clear when we're working with
// strings vs dynamics

// TODO: We need UUIDs

pub fn from_json() {
  use name <- decode.field("name", decode.string)
  use query <- decode.field("query", decode.string)
  decode.success(BoardConfig(name:, query:, statuses: statuses))
}

pub fn list_from_json(data: Dynamic) {
  let data_decoder = {
    use board_configs <- decode.field("board_configs", decode.list(from_json()))
    decode.success(board_configs)
  }

  data
  |> decode.run(decode.string)
  |> result.unwrap("{\"board_configs\": []}")
  |> json.parse(data_decoder)
  |> result.unwrap([])
}

pub fn to_json(board_config: BoardConfig) {
  json.object([
    #("name", json.string(board_config.name)),
    #("query", json.string(board_config.query)),
  ])
}

pub fn list_to_json(board_configs: List(BoardConfig)) {
  json.object([#("board_configs", json.array(board_configs, to_json))])
  |> json.to_string()
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
