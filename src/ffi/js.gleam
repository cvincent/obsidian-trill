import ffi/types.{type JSPrimitive}

@external(javascript, "src/ffi/js.ts", "call_method_bool")
pub fn call_method_bool(
  obj: any,
  method: String,
  args: List(JSPrimitive),
) -> Bool
