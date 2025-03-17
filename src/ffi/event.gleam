import ffi/obsidian/html_element.{type JSEvent}

@external(javascript, "src/ffi/event.ts", "prevent_default")
pub fn prevent_default(ev: JSEvent) -> Nil

@external(javascript, "src/ffi/event.ts", "stop_propagation")
pub fn stop_propagation(ev: JSEvent) -> Nil

@external(javascript, "src/ffi/event.ts", "stop_immediate_propagation")
pub fn stop_immediate_propagation(ev: JSEvent) -> Nil
