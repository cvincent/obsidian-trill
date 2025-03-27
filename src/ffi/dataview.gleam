import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}

pub type Page {
  Page(
    title: String,
    path: String,
    status: Result(String, String),
    original: Dynamic,
    content: Option(String),
  )
}

@external(javascript, "src/ffi/dataview.ts", "pages")
pub fn pages(query: string) -> List(Page)
