import gleam/list
import gleam/result
import gleam/string

pub fn wrap(str: String, width: Int, indent_size: Int) -> String {
  let indent = string.repeat(" ", indent_size)

  let words =
    str
    |> string.trim()
    |> string.split(" ")

  let assert [first, ..rest] = words
  let words = [indent <> first, ..rest]

  words
  |> list.reduce(fn(a, b) {
    let last_line =
      a
      |> string.split("\n")
      |> list.last()
      |> result.unwrap("")

    case string.length(last_line) + 1 + string.length(b) {
      l if l > width -> a <> "\n" <> indent <> b
      _ -> a <> " " <> b
    }
  })
  |> result.unwrap("")
}
