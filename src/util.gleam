import gleam/option.{type Option, Some}

pub fn then(data, func) {
  func(data)
}

pub fn option_guard(option: Option(inner), default: a, callback: fn(inner) -> a) {
  case option {
    Some(inner) -> callback(inner)
    _ -> default
  }
}
