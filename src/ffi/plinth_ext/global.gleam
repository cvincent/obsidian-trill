@external(javascript, "./global.ts", "set_global")
pub fn set_global(key: String, val: any) -> Nil

@external(javascript, "./global.ts", "get_string")
pub fn get_string(key: String) -> Result(String, Nil)
