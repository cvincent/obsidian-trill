import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import gleam/regexp
import gleam/result
import gleam/string
import line_wrap
import tempo

pub type Task {
  Task(
    mark: option.Option(String),
    text: String,
    line: Int,
    children: List(Task),
    fields: Dict(String, String),
  )
}

pub fn parse(task_list: String) -> List(Task) {
  let lines = string.split(task_list, "\n")
  parse_lines(lines, [], 0)
}

fn parse_lines(lines: List(String), tasks: List(Task), line: Int) -> List(Task) {
  case lines {
    [] -> Ok(list.reverse(tasks))
    ["- " <> _rest as first_task_line, ..rest] -> {
      let #(new_task, rest, new_line) =
        parse_new_task(first_task_line, rest, line)
      Ok(parse_lines(rest, [new_task, ..tasks], new_line))
    }
    _ -> Error(Nil)
  }
  |> result.unwrap([])
}

fn parse_new_task(
  first_task_line: String,
  rest_lines: List(String),
  line: Int,
) -> #(Task, List(String), Int) {
  let #(rest_task_lines, rest_lines) =
    list.split_while(rest_lines, fn(line) {
      case line {
        "  " <> _rest -> True
        _ -> False
      }
    })

  #(
    parse_task(first_task_line, rest_task_lines, line),
    rest_lines,
    line + list.length(rest_task_lines) + 1,
  )
}

fn parse_task(first_line: String, rest_lines: List(String), line: Int) -> Task {
  let #(mark, first_line) = case first_line {
    "- [" <> _rest -> {
      #(
        first_line
          |> string.drop_start(3)
          |> string.first()
          |> result.unwrap("")
          |> Some(),
        string.drop_start(first_line, 6),
      )
    }
    _ -> #(None, string.drop_start(first_line, 2))
  }

  let rest_lines = list.map(rest_lines, string.drop_start(_, 2))

  let #(rest_task_lines, child_task_lines) =
    list.split_while(rest_lines, fn(line) {
      case line {
        "- " <> _rest -> False
        _ -> True
      }
    })

  let task_text = string.join([first_line, ..rest_task_lines], " ")

  let #(task_text, fields) = extract_fields(task_text)

  Task(
    mark,
    task_text,
    line,
    parse_lines(child_task_lines, [], line + list.length(rest_task_lines) + 1),
    fields,
  )
}

fn extract_fields(task_text: String) -> #(String, Dict(String, String)) {
  let assert Ok(re) =
    regexp.from_string("\\[([A-Za-z0-9_-]+)::\\s+([^\\]]+)\\]")

  let matches = regexp.scan(re, task_text)

  let task_text =
    list.fold(matches, task_text, fn(acc, match) {
      string.replace(acc, match.content, "")
    })
    |> string.trim_end()

  let fields =
    list.map(matches, fn(match) {
      case match.submatches {
        [Some(key), Some(val)] -> Some(#(key, val))
        _ -> option.None
      }
    })
    |> option.values()
    |> dict.from_list()

  #(task_text, fields)
}

pub fn mark(tasks: List(Task), line: Int, mark: String) -> List(Task) {
  list.map(tasks, fn(task) {
    task
    |> maybe_mark(line, mark)
    |> result.unwrap_both()
  })
}

fn maybe_mark(task: Task, line: Int, mark: String) -> Result(Task, Task) {
  case task {
    task if task.line == line ->
      Ok(
        Task(
          ..task,
          mark: Some(mark),
          children: list.map(task.children, fn(subtask) {
            subtask
            |> maybe_mark(subtask.line, mark)
            |> result.unwrap_both()
          }),
          fields: update_fields(task.fields, mark),
        ),
      )

    task if task.line < line -> {
      let children = list.map(task.children, maybe_mark(_, line, mark))

      case result.values(children) {
        [] -> Error(task)
        _ ->
          Ok(mark_from_children(
            Task(..task, children: list.map(children, result.unwrap_both(_))),
          ))
      }
    }

    _ -> Error(task)
  }
}

// [" ", "-", "_", "x"]

fn mark_from_children(task: Task) -> Task {
  let child_marks =
    task.children
    |> list.filter_map(fn(subtask) {
      case subtask.mark {
        None -> Error(Nil)
        mark -> Ok(mark)
      }
    })
    |> list.unique()
    |> list.sort(fn(mark_a, mark_b) {
      string.compare(option.unwrap(mark_a, ""), option.unwrap(mark_b, ""))
    })

  case child_marks {
    [mark] ->
      Task(
        ..task,
        mark: mark,
        fields: update_fields(task.fields, option.unwrap(mark, "")),
      )
    [Some("_"), Some("x")] ->
      Task(..task, mark: Some("x"), fields: update_fields(task.fields, "x"))
    marks -> {
      case list.any(marks, fn(m) { m == Some("x") || m == Some("-") }) {
        True ->
          Task(..task, mark: Some("-"), fields: update_fields(task.fields, "-"))
        False -> task
      }
    }
  }
}

fn update_fields(
  fields: Dict(String, String),
  new_mark: String,
) -> Dict(String, String) {
  case new_mark {
    "x" -> {
      fields
      |> dict.delete("cancellation")
      |> dict.insert("completion", now())
    }
    "_" -> {
      fields
      |> dict.delete("completion")
      |> dict.insert("cancellation", now())
    }
    _ ->
      fields
      |> dict.delete("completion")
      |> dict.delete("cancellation")
  }
}

fn now() {
  tempo.format_local(tempo.ISO8601Seconds)
}

pub fn to_markdown(tasks: List(Task)) -> String {
  list.map(tasks, task_to_markdown(_, 0))
  |> string.join("\n")
}

fn task_to_markdown(task: Task, indent_size: Int) -> String {
  let indent = string.repeat(" ", indent_size)
  let bullet_indent = string.repeat(" ", indent_size) <> "- "

  let task_line =
    indent
    <> task_box_markdown(task)
    <> task.text
    <> " "
    <> fields_to_markdown(task.fields)

  let unbulleted =
    task_line
    |> line_wrap.wrap(80, indent_size + 2)
    |> string.drop_start(indent_size + 2)

  [
    bullet_indent <> unbulleted,
    ..list.map(task.children, task_to_markdown(_, indent_size + 2))
  ]
  |> string.join("\n")
}

fn task_box_markdown(task: Task) -> String {
  case task.mark {
    Some(mark) -> "[" <> mark <> "] "
    None -> ""
  }
}

fn fields_to_markdown(fields: Dict(String, String)) -> String {
  fields
  |> dict.to_list()
  |> list.sort(fn(a, b) {
    let #(ak, _) = a
    let #(bk, _) = b
    string.compare(ak, bk)
  })
  |> list.map(fn(kv) {
    let #(k, v) = kv
    "[" <> k <> ":: " <> v <> "]"
  })
  |> string.join(" ")
}
