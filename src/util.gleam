import gleam/option.{type Option, Some}
import lustre/element

pub fn then(data, func) {
  func(data)
}

pub fn option_guard(option: Option(inner), default: a, callback: fn(inner) -> a) {
  case option {
    Some(inner) -> callback(inner)
    _ -> default
  }
}

pub fn result_guard(
  result: Result(inner, err),
  default: a,
  callback: fn(inner) -> a,
) {
  case result {
    Ok(inner) -> callback(inner)
    _ -> default
  }
}

pub fn try_or_nil(
  result: Result(a, err),
  fun: fn(a) -> Result(b, Nil),
) -> Result(b, Nil) {
  case result {
    Ok(x) -> fun(x)
    Error(_err) -> Error(Nil)
  }
}

pub fn guard_element(cond: Bool, element) {
  case cond {
    True -> element
    False -> element.none()
  }
}
