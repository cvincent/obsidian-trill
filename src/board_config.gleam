import card_filter.{type CardFilter}
import ffi/plinth_ext/crypto
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string

pub type BoardConfig {
  BoardConfig(
    id: String,
    name: String,
    pinned: Bool,
    query: String,
    new_card_tags: List(String),
    columns: List(ColumnConfig),
    filter: CardFilter,
  )
}

pub fn encode_board_config(board_config: BoardConfig) -> json.Json {
  json.object([
    #("id", json.string(board_config.id)),
    #("name", json.string(board_config.name)),
    #("pinned", json.bool(board_config.pinned)),
    #("query", json.string(board_config.query)),
    #("new_card_tags", json.array(board_config.new_card_tags, json.string)),
    #("columns", json.array(board_config.columns, encode_column_config)),
    #("filter", card_filter.encode_card_filter(board_config.filter)),
  ])
}

pub fn board_config_decoder() -> decode.Decoder(BoardConfig) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use pinned <- decode.field("pinned", decode.bool)
  use query <- decode.field("query", decode.string)
  use new_card_tags <- decode.field("new_card_tags", decode.list(decode.string))
  use columns <- decode.field("columns", decode.list(column_config_decoder()))
  use filter <- decode.field("filter", card_filter.card_filter_decoder())
  decode.success(BoardConfig(
    id:,
    name:,
    pinned:,
    query:,
    new_card_tags:,
    columns:,
    filter:,
  ))
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
    pinned: False,
    query: "",
    new_card_tags: [],
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
    "comma_delimited_new_card_tags" ->
      BoardConfig(
        ..board_config,
        new_card_tags: value |> string.split(",") |> list.map(string.trim),
      )
    _ -> board_config
  }
}
