import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
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
  "done",
]

pub const new_board_config = BoardConfig("", "", statuses)

pub fn list_from_json(data: Dynamic) {
  let data_decoder = {
    use board_configs <- decode.field(
      "board_configs",
      decode.list({
        use name <- decode.field("name", decode.string)
        use query <- decode.field("query", decode.string)
        decode.success(BoardConfig(name:, query:, statuses: statuses))
      }),
    )
    decode.success(board_configs)
  }

  data
  |> decode.run(decode.string)
  |> result.unwrap("{\"board_configs\": []}")
  |> json.parse(data_decoder)
  |> result.unwrap([])
}

pub fn list_to_json(board_configs: List(BoardConfig)) {
  json.object([
    #(
      "board_configs",
      json.array(board_configs, fn(bc) {
        json.object([
          #("name", json.string(bc.name)),
          #("query", json.string(bc.query)),
        ])
      }),
    ),
  ])
  |> json.to_string()
}
