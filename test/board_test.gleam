import board.{Card, SourcePlaceholder, TargetPlaceholder}
import gleam/dict
import gleeunit/should
import util.{then}

fn test_board() {
  board.new_board(
    cards: [1, 2, 3],
    group_keys: ["inbox", "pending", "done"],
    group_key_fn: fn(int) {
      case int {
        1 -> "inbox"
        2 -> "pending"
        3 -> "done"
        _ -> "inbox"
      }
    },
    update_group_key_fn: fn(inner, _) { inner },
    null_status: "none",
    done_status: "done",
  )
}

pub fn board_constructor_test() {
  test_board().groups
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(1)]),
      #("pending", [Card(2)]),
      #("done", [Card(3)]),
    ]),
  )
}

pub fn add_card_test() {
  test_board()
  |> board.add_card(4)
  |> then(fn(board) { board.groups })
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(4), Card(1)]),
      #("pending", [Card(2)]),
      #("done", [Card(3)]),
    ]),
  )
}

pub fn start_dragging_test() {
  test_board()
  |> board.start_dragging(1)
  |> then(fn(board) { board.groups })
  |> should.equal(
    dict.from_list([
      #("inbox", [SourcePlaceholder(1)]),
      #("pending", [Card(2)]),
      #("done", [Card(3)]),
    ]),
  )
}

pub fn drag_over_test() {
  let board =
    test_board()
    |> board.add_card(5)
    |> board.add_card(4)

  let board =
    board
    |> board.start_dragging(2)
    |> board.drag_over(5, False)

  board.groups
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(4), TargetPlaceholder(2), Card(5), Card(1)]),
      #("pending", [SourcePlaceholder(2)]),
      #("done", [Card(3)]),
    ]),
  )

  board
  |> board.drag_over(5, True)
  |> then(fn(board) { board.groups })
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(4), Card(5), TargetPlaceholder(2), Card(1)]),
      #("pending", [SourcePlaceholder(2)]),
      #("done", [Card(3)]),
    ]),
  )

  board
  |> board.drag_over(4, True)
  |> then(fn(board) { board.groups })
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(4), TargetPlaceholder(2), Card(5), Card(1)]),
      #("pending", [SourcePlaceholder(2)]),
      #("done", [Card(3)]),
    ]),
  )

  board
  |> board.drag_over(4, False)
  |> then(fn(board) { board.groups })
  |> should.equal(
    dict.from_list([
      #("inbox", [TargetPlaceholder(2), Card(4), Card(5), Card(1)]),
      #("pending", [SourcePlaceholder(2)]),
      #("done", [Card(3)]),
    ]),
  )

  let board =
    test_board()
    |> board.add_card(5)
    |> board.add_card(4)

  let board =
    board
    |> board.start_dragging(5)
    |> board.drag_over(4, True)

  board.groups
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(4), SourcePlaceholder(5), Card(1)]),
      #("pending", [Card(2)]),
      #("done", [Card(3)]),
    ]),
  )

  board
  |> board.drag_over(1, False)
  |> then(fn(board) { board.groups })
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(4), SourcePlaceholder(5), Card(1)]),
      #("pending", [Card(2)]),
      #("done", [Card(3)]),
    ]),
  )

  board
  |> board.drag_over(1, True)
  |> then(fn(board) { board.groups })
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(4), SourcePlaceholder(5), Card(1), TargetPlaceholder(5)]),
      #("pending", [Card(2)]),
      #("done", [Card(3)]),
    ]),
  )
}

pub fn drop_test() {
  let board =
    test_board()
    |> board.add_card(5)
    |> board.add_card(4)

  board
  |> board.start_dragging(2)
  |> board.drag_over(5, False)
  |> board.drop()
  |> then(fn(ret) {
    let assert Ok(#(board, _)) = ret
    board.groups
  })
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(4), Card(2), Card(5), Card(1)]),
      #("pending", []),
      #("done", [Card(3)]),
    ]),
  )

  board
  |> board.start_dragging(2)
  |> board.drag_over(3, True)
  |> board.drop()
  |> then(fn(ret) {
    let assert Ok(#(board, _)) = ret
    board.groups
  })
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(4), Card(5), Card(1)]),
      #("pending", []),
      #("done", [Card(3), Card(2)]),
    ]),
  )

  board
  |> board.start_dragging(5)
  |> board.drag_over(4, True)
  |> board.drop()
  |> then(fn(ret) {
    let assert Ok(#(board, _)) = ret
    board.groups
  })
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(4), Card(5), Card(1)]),
      #("pending", [Card(2)]),
      #("done", [Card(3)]),
    ]),
  )
}

pub fn drag_over_column_test() {
  let board =
    test_board()
    |> board.start_dragging(1)
    |> board.drag_over(2, False)
    |> board.drop()
    |> then(fn(ret) {
      let assert Ok(#(board, _)) = ret
      board
    })

  board
  |> board.start_dragging(2)
  |> board.drag_over_column("inbox")
  |> board.drop()
  |> then(fn(ret) {
    let assert Ok(#(board, _)) = ret
    board.groups
  })
  |> should.equal(
    dict.from_list([
      #("inbox", [Card(2)]),
      #("pending", [Card(1)]),
      #("done", [Card(3)]),
    ]),
  )
}
