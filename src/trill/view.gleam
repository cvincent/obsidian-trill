import board.{type Card, Card}
import board_config
import board_config_form
import components
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/regexp
import gleam/result
import icons
import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event
import plinth/browser/event as pevent
import trill/defs.{type Model, type Msg}

pub fn view(model: Model) -> Element(Msg) {
  case model.board_config {
    Some(_board_config) -> board_view(model)
    None -> blank_view(model)
  }
}

fn blank_view(_model: Model) -> Element(Msg) {
  h.div(
    [attr.class("flex w-2/3 max-w-2xl justify-self-center items-center h-full")],
    [
      board_config_form.element(
        components.name,
        None,
        "user-submitted-new-board-form",
        "Create Board",
      ),
    ],
  )
}

fn board_view(model: Model) -> Element(Msg) {
  let assert Some(board) = model.board

  let assert Ok(null_status_cards) =
    dict.get(board.groups, board_config.null_status)

  let group_keys = case null_status_cards {
    [_card, ..] -> board.group_keys
    [] ->
      list.filter(board.group_keys, fn(gk) { gk != board_config.null_status })
  }

  h.div([], [
    h.div([attr.class("flex justify-start mb-2 gap-2")], [
      h.select(
        [
          attr.class("dropdown"),
          event.on_input(fn(value) {
            let assert Ok(board_config) =
              list.find(model.board_configs, fn(bc) { bc.name == value })
            defs.UserSelectedBoardConfig(board_config)
          }),
        ],
        list.map(model.board_configs, fn(board_config) {
          h.option(
            [
              attr.selected(Some(board_config) == model.board_config),
              // TODO: This should be a UUID
              attr.value(board_config.name),
            ],
            board_config.name,
          )
        }),
      ),
      h.div(
        [
          attr.class(
            "clickable-icon [--icon-size:var(--icon-s)] [--icon-stroke:var(--icon-s-stroke-width)]",
          ),
          event.on("click", fn(ev) { Ok(defs.UserClickedBoardMenu(ev)) }),
        ],
        [icons.icon("ellipsis-vertical")],
      ),
    ]),
    h.div(
      [attr.class("flex h-full")],
      list.map(group_keys, fn(status) {
        let assert Ok(cards) = dict.get(board.groups, status)
        let column_droppable = case cards {
          [] ->
            event.on("dragover", fn(event) {
              let assert Ok(event) = pevent.cast_event(event)
              Ok(defs.UserDraggedCardOverColumn(event, status))
            })

          _ -> attr.none()
        }

        let archive_all = case status {
          status if status == board_config.done_status ->
            h.a([event.on_click(defs.UserClickedArchiveAllDone)], [
              h.text("archive all"),
            ])
          _ -> element.none()
        }

        h.div(
          [attr.class("min-w-80 max-w-80 mr-4 height-full"), column_droppable],
          list.append(
            [
              h.div([attr.class("flex gap-2 mb-2")], [
                h.div([], [h.text(status)]),
                h.div([], [archive_all]),
              ]),
            ],
            list.map(cards, fn(card) {
              let page = card.inner

              let tasks =
                decode.run(
                  dynamic.from(page),
                  decode.at(
                    ["original", "file", "tasks"],
                    decode.list(decode.dynamic),
                  ),
                )

              let task_count =
                result.try(tasks, fn(tasks) { Ok(list.length(tasks)) })
                |> result.unwrap(0)

              let done_count =
                result.try(tasks, fn(tasks) {
                  list.count(tasks, fn(task) {
                    Ok("x")
                    == decode.run(task, decode.at(["status"], decode.string))
                  })
                  |> Ok()
                })
                |> result.unwrap(0)

              let task_info_color = case task_count - done_count {
                0 -> attr.class("text-(color:--text-muted)")
                _ -> attr.none()
              }

              let task_info = case task_count {
                task_count if task_count > 0 ->
                  h.div([attr.class("flex gap-1"), task_info_color], [
                    h.div([attr.class("[--icon-size:var(--icon-s)] mt-[1px]")], [
                      icons.icon("square-check"),
                    ]),
                    h.div([attr.class("align-middle")], [
                      h.text(
                        int.to_string(done_count)
                        <> "/"
                        <> int.to_string(task_count),
                      ),
                    ]),
                  ])
                _ -> element.none()
              }

              let content_preview = case page.content {
                Some(content) -> {
                  let assert Ok(re) = regexp.from_string("\\n# .+\\n")
                  case regexp.split(re, content) {
                    [_, content] ->
                      h.div(
                        [
                          attr.class(
                            "[display:-webkit-box] [-webkit-line-clamp:3] [-webkit-box-orient:vertical] overflow-hidden",
                          ),
                        ],
                        [h.text(content)],
                      )
                    _ -> element.none()
                  }
                }
                None -> element.none()
              }

              let invisible = case card {
                Card(_) -> ""
                _ -> "invisible"
              }

              let dragover = case card {
                Card(_) ->
                  event.on("dragover", fn(ev) {
                    let assert Ok(ev) = pevent.cast_event(ev)
                    Ok(defs.UserDraggedCardOverTarget(ev, card))
                  })

                _ -> attr.none()
              }

              h.div(
                [
                  attr.class("bg-(--background-secondary) mb-2 p-4 rounded-md"),
                  attr.attribute("draggable", "true"),
                  event.on("dragstart", fn(ev) {
                    Ok(defs.UserStartedDraggingCard(ev, card))
                  }),
                  event.on("dragend", fn(ev) {
                    Ok(defs.UserStoppedDraggingCard(ev))
                  }),
                  dragover,
                ],
                [
                  h.div([attr.class(invisible)], [
                    h.a(
                      [
                        attr.class("internal-link"),
                        attr.href(page.path),
                        event.on_click(defs.UserClickedInternalLink(page.path)),
                        event.on("mouseover", fn(ev) {
                          Ok(defs.UserHoveredInternalLink(ev, page.path))
                        }),
                      ],
                      [h.text(page.title)],
                    ),
                    task_info,
                    content_preview,
                    h.div([attr.class("flex justify-end")], [
                      h.a(
                        [
                          event.on_click(defs.UserClickedEditInNeoVim(page)),
                          attr.class("text-xs"),
                        ],
                        [h.text("nvim")],
                      ),
                    ]),
                  ]),
                ],
              )
            })
              |> list.append([
                h.div(
                  [
                    attr.class("h-full"),
                    event.on("dragover", fn(ev) {
                      let assert Ok(ev) = pevent.cast_event(ev)
                      Ok(defs.UserDraggedCardOverColumn(ev, status))
                    }),
                  ],
                  [],
                ),
              ]),
          ),
        )
      }),
    ),
  ])
}
