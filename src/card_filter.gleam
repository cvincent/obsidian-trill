import ffi/dataview.{type Page}
import gleam/bool
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type CardFilter {
  CardFilter(enabled: Bool, search: Option(String), tags: List(String))
}

pub fn encode_card_filter(card_filter: CardFilter) -> json.Json {
  json.object([
    #("enabled", json.bool(card_filter.enabled)),
    #("search", case card_filter.search {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #("tags", json.array(card_filter.tags, json.string)),
  ])
}

pub fn card_filter_decoder() -> decode.Decoder(CardFilter) {
  use enabled <- decode.field("enabled", decode.bool)
  use search <- decode.field("search", decode.optional(decode.string))
  use tags <- decode.field("tags", decode.list(decode.string))
  decode.success(CardFilter(enabled:, search:, tags:))
}

pub fn new() {
  CardFilter(enabled: True, search: None, tags: [])
}

pub fn match(card_filter: CardFilter, card: Page) {
  use <- bool.guard(!card_filter.enabled, True)

  let search = case card_filter.search {
    None -> True
    Some(search) ->
      string.contains(string.lowercase(card.title), string.lowercase(search))
  }

  let tags = case card_filter.tags {
    [] -> True
    tags -> list.any(card.tags, list.contains(tags, _))
  }

  search && tags
}

pub fn any(card_filter: CardFilter) {
  card_filter.enabled
  && { option.is_some(card_filter.search) || card_filter.tags != [] }
}
