import plinth/javascript/global.{type TimerID}

@external(javascript, "./global.ts", "set_global")
pub fn set_global(key: String, val: any) -> Nil

@external(javascript, "./global.ts", "get_string")
pub fn get_string(key: String) -> Result(String, Nil)

@external(javascript, "./global.ts", "get_int")
pub fn get_int(key: String) -> Result(Int, Nil)

@external(javascript, "./global.ts", "get_timer_id")
pub fn get_timer_id(key: String) -> Result(TimerID, Nil)
