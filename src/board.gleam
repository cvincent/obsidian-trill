import board_config.{type BoardConfig}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

// Why does a card _have_ to contain a page? It could be a board of anything...

pub type Board(group, inner) {
  Board(
    group_keys: List(group),
    groups: Dict(group, List(Card(inner))),
    dragging: Option(Card(inner)),
    group_key_fn: fn(inner) -> group,
    update_group_key_fn: fn(inner, group) -> inner,
  )
}

pub type Card(inner) {
  Card(inner: inner)
  SourcePlaceholder(inner: inner)
  TargetPlaceholder(inner: inner)
}

pub fn new_board(
  group_keys group_keys: List(group),
  cards cards: List(inner),
  group_key_fn group_key_fn: fn(inner) -> group,
  update_group_key_fn update_group_key_fn: fn(inner, group) -> inner,
) {
  let groups =
    group_keys
    |> list.map(fn(gk) {
      #(
        gk,
        list.filter_map(cards, fn(inner) {
          case group_key_fn(inner) == gk {
            True -> Ok(Card(inner))
            False -> Error(Nil)
          }
        }),
      )
    })
    |> dict.from_list()

  Board(
    group_keys:,
    groups:,
    dragging: None,
    group_key_fn:,
    update_group_key_fn:,
  )
}

pub fn add_card(board: Board(group, inner), card: inner) {
  let #(gk, group_cards) = gk_and_group_cards(board, card)
  let groups = dict.insert(board.groups, gk, [Card(card), ..group_cards])
  Board(..board, groups:)
}

pub fn start_dragging(board: Board(group, inner), inner: inner) {
  let #(gk, group_cards) = gk_and_group_cards(board, inner)

  let group_cards =
    group_cards
    |> list.map(fn(c) {
      case c {
        Card(c) if c == inner -> SourcePlaceholder(inner)
        c -> c
      }
    })

  let groups = dict.insert(board.groups, gk, group_cards)
  Board(..board, groups:, dragging: Some(Card(inner)))
}

pub fn drag_over(board: Board(group, inner), over: inner, after: Bool) {
  let assert Some(Card(dragging)) = board.dragging

  let groups =
    board.groups
    |> dict.map_values(fn(_gk, group_cards) {
      list.flat_map(group_cards, fn(card) {
        case card {
          TargetPlaceholder(_) -> []
          Card(c) if c == over -> {
            case after {
              True -> [Card(c), TargetPlaceholder(dragging)]
              False -> [TargetPlaceholder(dragging), Card(c)]
            }
          }
          any -> [any]
        }
      })
    })

  let over_gk = board.group_key_fn(over)
  let groups = remove_target_when_adjacent_to_source(groups, over_gk)

  Board(..board, groups:)
}

pub fn drag_over_column(board: Board(group, inner), col_gk: group) {
  let assert Some(Card(dragging)) = board.dragging

  let groups =
    board.groups
    |> dict.map_values(fn(gk, group_cards) {
      let group_cards =
        list.flat_map(group_cards, fn(card) {
          case card {
            TargetPlaceholder(_) -> []
            any -> [any]
          }
        })

      case gk == col_gk {
        True -> list.append(group_cards, [TargetPlaceholder(dragging)])
        False -> group_cards
      }
    })

  let groups = remove_target_when_adjacent_to_source(groups, col_gk)

  Board(..board, groups:)
}

fn remove_target_when_adjacent_to_source(
  groups: Dict(group, List(Card(inner))),
  group: group,
) {
  let assert Ok(group_cards) = dict.get(groups, group)

  let source_and_target_adjacent =
    group_cards
    |> list.window_by_2()
    |> list.any(fn(window) {
      case window {
        #(TargetPlaceholder(_), SourcePlaceholder(_)) -> True
        #(SourcePlaceholder(_), TargetPlaceholder(_)) -> True
        _ -> False
      }
    })

  case source_and_target_adjacent {
    False -> groups
    True ->
      dict.insert(
        groups,
        group,
        list.filter(group_cards, fn(card) {
          case card {
            TargetPlaceholder(_) -> False
            _ -> True
          }
        }),
      )
  }
}

pub fn drop(board: Board(group, inner)) {
  let assert Some(Card(dragging)) = board.dragging

  let target =
    board.groups
    |> dict.to_list()
    |> list.find_map(fn(gk_and_cards) {
      let #(gk, cards) = gk_and_cards

      list.find_map(cards, fn(card) {
        case card {
          TargetPlaceholder(_) -> Ok(gk)
          _ -> Error(Nil)
        }
      })
    })

  let assert Ok(new_gk) = result.or(target, Ok(board.group_key_fn(dragging)))
  let dragging = board.update_group_key_fn(dragging, new_gk)

  let groups =
    board.groups
    |> dict.map_values(fn(_gk, group_cards) {
      list.flat_map(group_cards, fn(card) {
        case card {
          TargetPlaceholder(_) -> [Card(dragging)]
          SourcePlaceholder(_) -> {
            case target {
              Ok(_) -> []
              Error(_) -> [Card(dragging)]
            }
          }
          any -> [any]
        }
      })
    })

  #(Board(..board, groups:, dragging: None), new_gk)
}

pub fn update_cards(
  board: Board(group, inner),
  func: fn(Card(inner)) -> Card(inner),
) {
  let groups =
    dict.map_values(board.groups, fn(_gk, group_cards) {
      list.map(group_cards, func)
    })
  Board(..board, groups: groups)
}

fn gk_and_group_cards(board: Board(group, inner), card: inner) {
  let gk = board.group_key_fn(card)
  let assert Ok(group_cards) = dict.get(board.groups, gk)
  #(gk, group_cards)
}
