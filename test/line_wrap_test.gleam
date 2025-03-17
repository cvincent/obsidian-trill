import gleam/string
import gleeunit
import gleeunit/should
import line_wrap

pub fn main() {
  gleeunit.main()
}

pub fn line_wrap_test() {
  "aaaaa aaaa aaa aa a aa aa aaa a a aaa aaaaaaaaaa a"
  |> line_wrap.wrap(5, 0)
  |> string.split("\n")
  |> should.equal([
    "aaaaa", "aaaa", "aaa", "aa a", "aa aa", "aaa a", "a aaa", "aaaaaaaaaa", "a",
  ])

  "aaaaa aaaa aaa aa a aa aa aaa a a aaa aaaaaaaaaa a"
  |> line_wrap.wrap(7, 2)
  |> string.split("\n")
  |> should.equal([
    "  aaaaa", "  aaaa", "  aaa", "  aa a", "  aa aa", "  aaa a", "  a aaa",
    "  aaaaaaaaaa", "  a",
  ])
}

pub fn line_wrap_invalid_test() {
  ""
  |> line_wrap.wrap(5, 0)
  |> should.equal("")

  "a"
  |> line_wrap.wrap(5, 0)
  |> should.equal("a")

  "aaaaaa"
  |> line_wrap.wrap(5, 0)
  |> should.equal("aaaaaa")

  ""
  |> line_wrap.wrap(7, 2)
  |> should.equal("  ")

  "a"
  |> line_wrap.wrap(7, 2)
  |> should.equal("  a")

  "aaaaaa"
  |> line_wrap.wrap(7, 2)
  |> should.equal("  aaaaaa")
}
