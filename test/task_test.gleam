import gleeunit
import gleeunit/should
import task.{Task}
import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import tempo/datetime
import tempo/mock

const now = "2025-01-01T12:00:00-05:00"

pub fn main() {
  gleeunit.main()
}

fn freeze_time() {
  let assert Ok(dt) = datetime.from_string("2025-01-01 12:00:00-05:00")
  mock.freeze_time(dt)
}

pub fn parse_simple_test() {
  freeze_time()

  [
    "- [ ] Task 1",
    "- [x] Task 2"
  ]
  |> string.join("\n")
  |> task.parse()
  |> should.equal([
    Task(Some(" "), "Task 1", 0, [], dict.new()),
    Task(Some("x"), "Task 2", 1, [], dict.new())
  ])
}

pub fn parse_multiline_test() {
  [
    "- [ ] Task 1 wraps across multiple",
    "  lines like this",
    "- [x] Task 2 wraps even",
    "  more lines",
    "  than the previous",
    "- [ ] To test line number tracking"
  ]
  |> string.join("\n")
  |> task.parse()
  |> should.equal([
    Task(Some(" "), "Task 1 wraps across multiple lines like this", 0, [], dict.new()),
    Task(Some("x"), "Task 2 wraps even more lines than the previous", 2, [], dict.new()),
    Task(Some(" "), "To test line number tracking", 5, [], dict.new()),
  ])
}

pub fn parse_children_test() {
  [
    "- [ ] Parent task",
    "  - [ ] Child task 1",
    "  - [ ] Child task 2",
    "- [ ] Final task"
  ]
  |> string.join("\n")
  |> task.parse()
  |> should.equal([
    Task(Some(" "), "Parent task", 0, [
      Task(Some(" "), "Child task 1", 1, [], dict.new()),
      Task(Some(" "), "Child task 2", 2, [], dict.new()),
    ], dict.new()),
    Task(Some(" "), "Final task", 3, [], dict.new()),
  ])
}

pub fn parse_metadata_test() {
  [
    "- [ ] Task [field1:: val1] [field2:: val2]",
    "- [ ] Task that wraps and",
    "  has metadata [field:: val]",
    "- [ ] Task that wraps and [field::",
    "  wraps-too]"
  ]
  |> string.join("\n")
  |> task.parse()
  |> should.equal([
    Task(Some(" "), "Task", 0, [], dict.from_list([#("field1", "val1"), #("field2", "val2")])),
    Task(Some(" "), "Task that wraps and has metadata", 1, [], dict.from_list([#("field", "val")])),
    Task(Some(" "), "Task that wraps and", 3, [], dict.from_list([#("field", "wraps-too")])),
  ])
}

pub fn parse_non_task_items_test() {
  [
    "- Non-task",
    "  - Child non-task",
    "  - [ ] Child task",
    "- [ ] Parent task",
    "  - Child non-task",
    "  - [ ] Child task",
  ]
  |> string.join("\n")
  |> task.parse()
  |> should.equal([
    Task(None, "Non-task", 0, fields: dict.new(), children: [
      Task(None, "Child non-task", 1, fields: dict.new(), children: []),
      Task(Some(" "), "Child task", 2, fields: dict.new(), children: []),
    ]),
    Task(Some(" "), "Parent task", 3, fields: dict.new(), children: [
      Task(None, "Child non-task", 4, fields: dict.new(), children: []),
      Task(Some(" "), "Child task", 5, fields: dict.new(), children: []),
    ]),
  ])
}

pub fn parse_test() {
  let task_list =
    [
      "- [ ] Simple task",
      "- [x] Done task [completed:: 1234-04-05] [another:: field]",
      "- [ ] Parent task",
      "  - [ ] Child task 1",
      "  - [ ] Child task 2",
      "- [ ] Multiline task that goes and goes and",
      "  goes and goes and goes",
      "  - [ ] Multiline child task that goes and",
      "    goes and goes and goes",
      "    - [ ] Subchild of multiline",
      "  - [ ] Multiline child task 2",
      "- [ ] Multiline task with fields and the",
      "  field is [field:: cool] [wraps::",
      "  like-so]",
      "- [ ] Final task"
    ]
    |> string.join("\n")

  let tasks = task.parse(task_list)

  tasks |> should.equal([
    Task(Some(" "), "Simple task", 0, [], dict.new()),
    Task(Some("x"), "Done task", 1, [], dict.from_list([
      #("completed", "1234-04-05"),
      #("another", "field")
    ])),
    Task(Some(" "), "Parent task", 2, [
      Task(Some(" "), "Child task 1", 3, [], dict.new()),
      Task(Some(" "), "Child task 2", 4, [], dict.new()),
    ], dict.new()),
    Task(Some(" "), "Multiline task that goes and goes and goes and goes and goes", 5, [
      Task(Some(" "), "Multiline child task that goes and goes and goes and goes", 7, [
        Task(Some(" "), "Subchild of multiline", 9, [], dict.new()),
      ], dict.new()),
      Task(Some(" "), "Multiline child task 2", 10, [], dict.new()),
    ], dict.new()),
    Task(Some(" "), "Multiline task with fields and the field is", 11, [], dict.from_list([
      #("field", "cool"),
      #("wraps", "like-so")
    ])),
    Task(Some(" "), "Final task", 14, [], dict.new()),
  ])
}

fn mark_test_tasks() {
  [
    Task(Some(" "), "Parent", 0, fields: dict.new(), children: [
      Task(Some(" "), "Child 1", 1, fields: dict.new(), children: []),
      Task(Some(" "), "Child 2", 2, fields: dict.new(), children: []),
    ]),
    Task(Some(" "), "Final", 3, fields: dict.new(), children: [])
  ]
}

pub fn mark_simple_test() {
  freeze_time()

  mark_test_tasks()
  |> task.mark(3, "x")
  |> should.equal([
    Task(Some(" "), "Parent", 0, fields: dict.new(), children: [
      Task(Some(" "), "Child 1", 1, fields: dict.new(), children: []),
      Task(Some(" "), "Child 2", 2, fields: dict.new(), children: []),
    ]),
    Task(Some("x"), "Final", 3, fields: dict.from_list([#("completion", now)]), children: [])
  ])
}

pub fn mark_parent_test() {
  freeze_time()

  mark_test_tasks()
  |> task.mark(0, "x")
  |> should.equal([
    Task(Some("x"), "Parent", 0, fields: dict.from_list([#("completion", now)]), children: [
      Task(Some("x"), "Child 1", 1, fields: dict.from_list([#("completion", now)]), children: []),
      Task(Some("x"), "Child 2", 2, fields: dict.from_list([#("completion", now)]), children: []),
    ]),
    Task(Some(" "), "Final", 3, fields: dict.new(), children: [])
  ])
}

pub fn mark_child_test() {
  freeze_time()

  mark_test_tasks()
  |> task.mark(1, "x")
  |> should.equal([
    Task(Some("-"), "Parent", 0, fields: dict.new(), children: [
      Task(Some("x"), "Child 1", 1, fields: dict.from_list([#("completion", now)]), children: []),
      Task(Some(" "), "Child 2", 2, fields: dict.new(), children: []),
    ]),
    Task(Some(" "), "Final", 3, fields: dict.new(), children: [])
  ])
}

pub fn mark_child_with_canceled_test() {
  freeze_time()

  mark_test_tasks()
  |> task.mark(1, "_")
  |> task.mark(2, "x")
  |> should.equal([
    Task(Some("x"), "Parent", 0, fields: dict.from_list([#("completion", now)]), children: [
      Task(Some("_"), "Child 1", 1, fields: dict.from_list([#("cancellation", now)]), children: []),
      Task(Some("x"), "Child 2", 2, fields: dict.from_list([#("completion", now)]), children: []),
    ]),
    Task(Some(" "), "Final", 3, fields: dict.new(), children: [])
  ])
}

pub fn mark_deep_child_test() {
  freeze_time()

  [
    Task(Some(" "), "Parent", 0, fields: dict.new(), children: [
      Task(Some(" "), "Child 1", 1, fields: dict.new(), children: [
        Task(Some(" "), "Child 2", 2, fields: dict.new(), children: [
          Task(Some(" "), "Child 3", 3, fields: dict.new(), children: []),
          Task(Some(" "), "Child 4", 4, fields: dict.new(), children: []),
        ])
      ]),
    ])
  ]
  |> task.mark(4, "x")
  |> should.equal([
    Task(Some("-"), "Parent", 0, fields: dict.new(), children: [
      Task(Some("-"), "Child 1", 1, fields: dict.new(), children: [
        Task(Some("-"), "Child 2", 2, fields: dict.new(), children: [
          Task(Some(" "), "Child 3", 3, fields: dict.new(), children: []),
          Task(Some("x"), "Child 4", 4, fields: dict.from_list([#("completion", now)]), children: []),
        ])
      ]),
    ])
  ])

  [
    Task(Some(" "), "Parent", 0, fields: dict.new(), children: [
      Task(Some(" "), "Child 1", 1, fields: dict.new(), children: [
        Task(Some(" "), "Child 2", 2, fields: dict.new(), children: [
          Task(Some(" "), "Child 3", 3, fields: dict.new(), children: []),
          Task(Some("x"), "Child 4", 4, fields: dict.from_list([#("completion", now)]), children: []),
        ])
      ]),
    ])
  ]
  |> task.mark(3, "x")
  |> should.equal([
    Task(Some("x"), "Parent", 0, fields: dict.from_list([#("completion", now)]), children: [
      Task(Some("x"), "Child 1", 1, fields: dict.from_list([#("completion", now)]), children: [
        Task(Some("x"), "Child 2", 2, fields: dict.from_list([#("completion", now)]), children: [
          Task(Some("x"), "Child 3", 3, fields: dict.from_list([#("completion", now)]), children: []),
          Task(Some("x"), "Child 4", 4, fields: dict.from_list([#("completion", now)]), children: []),
        ])
      ]),
    ])
  ])

  [
    Task(Some(" "), "Parent", 0, fields: dict.new(), children: [
      Task(Some(" "), "Child 1", 1, fields: dict.new(), children: [
        Task(Some(" "), "Child 2", 2, fields: dict.new(), children: [
          Task(Some(" "), "Child 3", 3, fields: dict.new(), children: []),
          Task(Some("x"), "Child 4", 4, fields: dict.from_list([#("completion", now)]), children: []),
        ])
      ]),
    ])
  ]
  |> task.mark(3, "_")
  |> should.equal([
    Task(Some("x"), "Parent", 0, fields: dict.from_list([#("completion", now)]), children: [
      Task(Some("x"), "Child 1", 1, fields: dict.from_list([#("completion", now)]), children: [
        Task(Some("x"), "Child 2", 2, fields: dict.from_list([#("completion", now)]), children: [
          Task(Some("_"), "Child 3", 3, fields: dict.from_list([#("cancellation", now)]), children: []),
          Task(Some("x"), "Child 4", 4, fields: dict.from_list([#("completion", now)]), children: []),
        ])
      ]),
    ])
  ])
}

pub fn unmark_test() {
  freeze_time()

  [
    Task(Some("-"), "Parent", 0, fields: dict.new(), children: [
      Task(Some("x"), "Child 1", 1, fields: dict.from_list([#("completion", now)]), children: []),
      Task(Some(" "), "Child 2", 2, fields: dict.new(), children: []),
    ])
  ]
  |> task.mark(1, " ")
  |> should.equal([
    Task(Some(" "), "Parent", 0, fields: dict.new(), children: [
      Task(Some(" "), "Child 1", 1, fields: dict.new(), children: []),
      Task(Some(" "), "Child 2", 2, fields: dict.new(), children: []),
    ])
  ])

  [
    Task(Some("x"), "Parent", 0, fields: dict.from_list([#("completion", now)]), children: [
      Task(Some("x"), "Child 1", 1, fields: dict.from_list([#("completion", now)]), children: []),
      Task(Some("x"), "Child 2", 2, fields: dict.from_list([#("completion", now)]), children: []),
    ])
  ]
  |> task.mark(1, " ")
  |> should.equal([
    Task(Some("-"), "Parent", 0, fields: dict.new(), children: [
      Task(Some(" "), "Child 1", 1, fields: dict.new(), children: []),
      Task(Some("x"), "Child 2", 2, fields: dict.from_list([#("completion", now)]), children: []),
    ])
  ])
}

pub fn to_markdown_test() {
  [
    Task(Some(" "), "Simple task", 0, [], dict.new()),
    Task(Some("x"), "Done task", 1, [], dict.from_list([
      #("another", "field"),
      #("completed", "1234-04-05"),
    ])),
    Task(Some(" "), "Parent task", 2, [
      Task(Some(" "), "Child task 1", 3, [], dict.new()),
      Task(Some(" "), "Child task 2", 4, [], dict.new()),
    ], dict.new()),
    Task(Some(" "), "Multiline task that goes and goes and goes and goes and goes and goes and goes and goes and goes", 5, [
      Task(Some(" "), "Multiline task that goes and goes and goes and goes and goes and goes and goes and goes and goes", 7, [
        Task(Some(" "), "Subchild of multiline", 9, [], dict.new()),
      ], dict.new()),
      Task(Some(" "), "Multiline child task 2", 10, [], dict.new()),
    ], dict.new()),
    Task(Some(" "), "Multiline task with fields and goes and goes and goes", 11, [], dict.from_list([
      #("the", "field-it-must"),
      #("wrap", "like-so"),
      #("multiple-fkn", "times"),
    ])),
    Task(Some(" "), "Final task", 14, [], dict.new()),
  ]
  |> task.to_markdown()
  |> string.split("\n")
  |> should.equal([
    "- [ ] Simple task",
    "- [x] Done task [another:: field] [completed:: 1234-04-05]",
    "- [ ] Parent task",
    "  - [ ] Child task 1",
    "  - [ ] Child task 2",
    "- [ ] Multiline task that goes and goes and goes and goes and goes and goes and",
    "  goes and goes and goes",
    "  - [ ] Multiline task that goes and goes and goes and goes and goes and goes",
    "    and goes and goes and goes",
    "    - [ ] Subchild of multiline",
    "  - [ ] Multiline child task 2",
    "- [ ] Multiline task with fields and goes and goes and goes [multiple-fkn::",
    "  times] [the:: field-it-must] [wrap:: like-so]",
    "- [ ] Final task",
  ])
}
