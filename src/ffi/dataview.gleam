pub type Page {
  Page(title: String, path: String, status: Result(String, String))
}

@external(javascript, "src/ffi/dataview.ts", "pages")
pub fn pages(query: string) -> List(Page)
