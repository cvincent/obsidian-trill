import card_filter.{type CardFilter}
import ffi/plinth_ext/crypto
import gleam/dynamic/decode
import gleam/json

pub type BoardConfig {
  BoardConfig(
    id: String,
    name: String,
    query: String,
    statuses: List(String),
    filter: CardFilter,
  )
}

pub fn encode_board_config(board_config: BoardConfig) -> json.Json {
  json.object([
    #("id", json.string(board_config.id)),
    #("name", json.string(board_config.name)),
    #("query", json.string(board_config.query)),
    #("statuses", json.array(board_config.statuses, json.string)),
    #("filter", card_filter.encode_card_filter(board_config.filter)),
  ])
}

pub fn board_config_decoder() -> decode.Decoder(BoardConfig) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use query <- decode.field("query", decode.string)
  use statuses <- decode.field("statuses", decode.list(decode.string))
  use filter <- decode.field("filter", card_filter.card_filter_decoder())
  decode.success(BoardConfig(id:, name:, query:, statuses:, filter:))
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

pub fn new() {
  BoardConfig(
    id: crypto.random_uuid(),
    name: "",
    query: "",
    statuses:,
    filter: card_filter.new(),
  )
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
