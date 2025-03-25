import gleam/dynamic.{type Dynamic}

pub type Page {
  Page(
    title: String,
    path: String,
    status: Result(String, String),
    original: Dynamic,
  )
}

@external(javascript, "src/ffi/dataview.ts", "pages")
pub fn pages(query: string) -> List(Page)
