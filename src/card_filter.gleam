import ffi/console
import ffi/dataview.{type Page}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/string

pub type CardFilter {
  CardFilter(search: Option(String))
}

pub fn encode_card_filter(card_filter: CardFilter) -> json.Json {
  json.object([
    #("search", case card_filter.search {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
  ])
}

pub fn card_filter_decoder() -> decode.Decoder(CardFilter) {
  use search <- decode.field("search", decode.optional(decode.string))
  decode.success(CardFilter(search:))
}

pub fn new() {
  CardFilter(search: None)
}

pub fn match(card_filter: CardFilter, card: Page) {
  case card_filter.search {
    None -> True
    Some(search) ->
      string.contains(string.lowercase(card.title), string.lowercase(search))
  }
}

pub fn any(card_filter: CardFilter) {
  case card_filter.search {
    None -> False
    _ -> True
  }
}
