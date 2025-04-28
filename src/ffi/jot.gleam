// This calls some custom JS in my personal vault; at some point we ought to
// generalize so users can specify their own way of creating cards
@external(javascript, "src/ffi/jot.ts", "jot")
pub fn jot(tags: List(String)) -> Nil
