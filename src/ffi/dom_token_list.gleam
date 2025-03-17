import plinth/browser/dom_token_list.{type DomTokenList}

@external(javascript, "src/ffi/dom_token_list.ts", "contains")
pub fn contains(dtl: DomTokenList, val: String) -> Bool
