import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import util

// Why does a card _have_ to contain a page? It could be a board of anything...

pub type Board(group, inner) {
  Board(
    group_keys: List(group),
    groups: Dict(group, List(Card(inner))),
    dragging: Option(Card(inner)),
    group_key_fn: fn(inner) -> group,
    update_group_key_fn: fn(inner, group) -> inner,
    null_status: String,
    done_status: String,
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
  null_status null_status: String,
  done_status done_status: String,
) {
  let groups = groups_from_cards(group_keys, group_key_fn, cards)

  Board(
    group_keys:,
    groups:,
    dragging: None,
    group_key_fn:,
    update_group_key_fn:,
    null_status:,
    done_status:,
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
  use dragging <- util.option_guard(board.dragging, board)
  let dragging = dragging.inner

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
  use dragging <- util.option_guard(board.dragging, board)
  let dragging = dragging.inner

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
  use group_cards <- util.result_guard(dict.get(groups, group), groups)

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

  use <- bool.guard(!source_and_target_adjacent, groups)

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

pub fn drop(
  board: Board(group, inner),
) -> Result(#(Board(group, inner), Result(group, group)), Nil) {
  use dragging <- util.option_guard(board.dragging, Error(Nil))
  let dragging = dragging.inner

  let target =
    board.groups
    |> dict.to_list()
    |> list.find_map(fn(gk_and_cards) {
      let #(gk, cards) = gk_and_cards

      list.find_map(cards, fn(card) {
        case card {
          TargetPlaceholder(_) -> Ok(gk)
          _ -> Error(board.group_key_fn(dragging))
        }
      })
    })
    |> result.replace_error(board.group_key_fn(dragging))

  let dragging = board.update_group_key_fn(dragging, result.unwrap_both(target))

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

  #(Board(..board, groups:, dragging: None), target) |> Ok()
}

pub fn set_cards(board: Board(group, inner), cards: List(inner)) {
  let groups = groups_from_cards(board.group_keys, board.group_key_fn, cards)
  Board(..board, groups:)
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
  case dict.get(board.groups, gk) {
    Ok(group_cards) -> #(gk, group_cards)
    Error(_) -> #(gk, [])
  }
}

fn groups_from_cards(
  group_keys: List(group),
  group_key_fn: fn(inner) -> group,
  cards: List(inner),
) {
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
}
