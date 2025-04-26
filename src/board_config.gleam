import card_filter.{type CardFilter}
import ffi/plinth_ext/crypto
import gleam/dynamic/decode
import gleam/json
import gleam/list

pub type BoardConfig {
  BoardConfig(
    id: String,
    name: String,
    query: String,
    columns: List(ColumnConfig),
    filter: CardFilter,
  )
}

pub fn encode_board_config(board_config: BoardConfig) -> json.Json {
  json.object([
    #("id", json.string(board_config.id)),
    #("name", json.string(board_config.name)),
    #("query", json.string(board_config.query)),
    #("columns", json.array(board_config.columns, encode_column_config)),
    #("filter", card_filter.encode_card_filter(board_config.filter)),
  ])
}

pub fn board_config_decoder() -> decode.Decoder(BoardConfig) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use query <- decode.field("query", decode.string)
  use columns <- decode.optional_field(
    "columns",
    list.map(default_statuses, ColumnConfig(status: _, hide_if_empty: False)),
    decode.list(column_config_decoder()),
  )
  use filter <- decode.field("filter", card_filter.card_filter_decoder())
  decode.success(BoardConfig(id:, name:, query:, columns:, filter:))
}

pub type ColumnConfig {
  ColumnConfig(status: String, hide_if_empty: Bool)
}

fn encode_column_config(column_config: ColumnConfig) -> json.Json {
  json.object([
    #("status", json.string(column_config.status)),
    #("hide_if_empty", json.bool(column_config.hide_if_empty)),
  ])
}

fn column_config_decoder() -> decode.Decoder(ColumnConfig) {
  use status <- decode.field("status", decode.string)
  use hide_if_empty <- decode.field("hide_if_empty", decode.bool)
  decode.success(ColumnConfig(status:, hide_if_empty:))
}

pub const null_status = "none"

pub const done_status = "done"

pub const default_statuses = [
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
    columns: list.map(default_statuses, ColumnConfig(
      status: _,
      hide_if_empty: False,
    )),
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
