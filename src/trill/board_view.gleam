import board.{type Board, type Card, Card}
import board_config.{type BoardConfig, BoardConfig}
import ffi/dataview.{type Page, Page}
import ffi/neovim
import ffi/obsidian/vault
import ffi/plinth_ext/element as pxelement
import ffi/plinth_ext/event as pxevent
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import icons
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html as h
import lustre/event
import obsidian_context.{type ObsidianContext} as obs
import plinth/browser/element as pelement
import plinth/browser/event.{type Event as PEvent} as pevent
import tempo
import trill/internal_link
import util.{option_guard}

// Our modal _could_ just be an actual Board, but we will probably be passing
// more into this view later. In particular, the page content cache I have in
// mind. So we'll wrap the board in a record in anticipation of that.
pub type Model {
  Model(
    obs: ObsidianContext,
    board_config: BoardConfig,
    board: Board(String, Page),
  )
}

pub fn new(obs: ObsidianContext, board_config: BoardConfig) {
  // TODO: We will revisit this with a proper way to load content previews
  // let assert Some(#(board, effect)) =
  //   option.map(board_config, fn(board_config) {
  //     let effect =
  //       effect.from(fn(dispatch) {
  //         list.map(pages, fn(page) {
  //           vault.get_file_by_path(model.obs.vault, page.path)
  //           |> result.try(fn(file) {
  //             vault.cached_read(model.obs.vault, file)
  //             |> promise.map(fn(content) { #(page.path, content) })
  //             |> Ok()
  //           })
  //         })
  //         |> result.values()
  //         |> promise.await_list()
  //         |> promise.map(fn(contents) {
  //           dispatch(ObsidianReadPageContents(dict.from_list(contents)))
  //         })
  //         Nil
  //       })

  //     #(board, effect.none())
  //   })

  let board = new_board_from_config(board_config)
  Model(obs:, board_config:, board:)
}

pub fn update_board_config(board_view: Model, board_config: BoardConfig) {
  Model(..board_view, board_config:, board: new_board_from_config(board_config))
}

fn new_board_from_config(board_config: BoardConfig) {
  let pages = dataview.pages(board_config.query)

  board.new_board(
    group_keys: board_config.statuses,
    cards: pages,
    group_key_fn: group_key_fn,
    update_group_key_fn: update_group_key_fn,
    null_status: board_config.null_status,
    done_status: board_config.done_status,
  )
}

fn group_key_fn(page: Page) {
  result.unwrap(page.status, board_config.null_status)
}

fn update_group_key_fn(page: Page, new_status: String) {
  let status = case new_status {
    s if s == board_config.null_status -> Error(board_config.null_status)
    s -> Ok(s)
  }
  Page(..page, status:)
}

pub type Msg {
  InternalLinkMsg(internal_link.Msg)

  UserStartedDraggingCard(event: Dynamic, card: Card(Page))
  UserStoppedDraggingCard(event: Dynamic)
  // TODO: See if we can just use Dynamic here, and do it consistently, now that
  // we know how
  UserDraggedCardOverTarget(event: PEvent(Dynamic), over: Card(Page))
  UserDraggedCardOverColumn(over: String)
  UserClickedEditInNeoVim(file: Page)
  UserClickedArchiveAllDone
  BoardViewArchivedAll

  ObsidianReadPageContents(contents: Dict(String, String))
}

type Update =
  #(Model, Effect(Msg))

pub fn update(model: Model, msg: Msg) -> Update {
  case msg {
    InternalLinkMsg(internal_link_msg) -> {
      let #(_internal_link_model, effect) =
        internal_link.update(internal_link_msg)
      #(model, effect.map(effect, InternalLinkMsg))
    }

    UserStartedDraggingCard(_, card) -> #(
      Model(..model, board: board.start_dragging(model.board, card.inner)),
      effect.none(),
    )

    UserStoppedDraggingCard(_) -> {
      let card = model.board.dragging
      use #(board, new_status) <- util.result_guard(board.drop(model.board), #(
        model,
        effect.none(),
      ))

      #(Model(..model, board:), effect.none())
      |> maybe_write_new_status(card, new_status)
    }

    UserDraggedCardOverTarget(event, over_card) -> {
      {
        use target_card_el <- result.try(
          event
          |> pevent.target()
          |> pelement.cast()
          |> result.replace_error(Nil),
        )
        use target_card_el <- result.try(pelement.closest(
          target_card_el,
          "[draggable=true]",
        ))

        let target = pxelement.get_bounding_client_rect(target_card_el)
        let mouse = pxevent.get_client_coords(event)

        let top_dist = int.absolute_value(target.top - mouse.y)
        let bot_dist = int.absolute_value(target.top + target.height - mouse.y)

        let after = bot_dist < top_dist

        #(
          Model(
            ..model,
            board: board.drag_over(model.board, over_card.inner, after),
          ),
          effect.none(),
        )
        |> Ok()
      }
      |> result.replace_error(#(model, effect.none()))
      |> result.unwrap_both()
    }

    UserDraggedCardOverColumn(over_column) -> {
      #(
        Model(..model, board: board.drag_over_column(model.board, over_column)),
        effect.none(),
      )
    }

    UserClickedArchiveAllDone -> {
      let effect =
        effect.from(fn(dispatch) {
          model.board.groups
          |> dict.get(model.board.done_status)
          |> result.unwrap([])
          |> list.each(fn(card) {
            let assert Card(page) = card
            obs.add_tag(model.obs, page.path, "archive")
            page
          })

          dispatch(BoardViewArchivedAll)
        })

      #(model, effect)
    }

    BoardViewArchivedAll -> {
      #(update_board_config(model, model.board_config), effect.none())
    }

    UserClickedEditInNeoVim(page) -> {
      let effect =
        effect.from(fn(_dispatch) {
          let _ = {
            use file <- result.map(vault.get_file_by_path(
              model.obs.vault,
              page.path,
            ))
            use neovim <- result.map(decode.run(
              dynamic.from(model.obs.app),
              decode.at(
                ["plugins", "plugins", "edit-in-neovim", "neovim"],
                decode.dynamic,
              ),
            ))
            neovim.open_file(model.obs.vault, neovim, file)
          }
          Nil
        })

      #(model, effect)
    }

    ObsidianReadPageContents(contents) -> {
      let board =
        board.update_cards(model.board, fn(card) {
          let assert Card(page) = card
          let content =
            page.path
            |> dict.get(contents, _)
            |> option.from_result()
          Card(Page(..page, content: content))
        })

      #(Model(..model, board:), effect.none())
    }
  }
}

fn maybe_write_new_status(
  update: Update,
  card: Option(Card(Page)),
  new_status: Result(String, String),
) -> Update {
  let #(model, effects) = update

  let effect = {
    use <- bool.guard(result.is_ok(new_status), effect.none())
    use card <- option_guard(card, effect.none())
    use _ <- effect.from

    let page = card.inner
    let board = model.board
    let new_status = result.unwrap_both(new_status)

    case new_status {
      new_status if new_status == board.done_status -> {
        obs.set_front_matter(model.obs, page.path, "status", Some(new_status))
        obs.set_front_matter(
          model.obs,
          page.path,
          "done",
          Some(tempo.format_local(tempo.ISO8601Seconds)),
        )
      }

      new_status if new_status == board.null_status -> {
        obs.set_front_matter(model.obs, page.path, "status", None)
        obs.set_front_matter(model.obs, page.path, "done", None)
      }

      new_status -> {
        obs.set_front_matter(model.obs, page.path, "status", Some(new_status))
        obs.set_front_matter(model.obs, page.path, "done", None)
      }
    }
  }

  #(model, effect.batch([effect, effects]))
}

pub fn view(model: Model) {
  let board = model.board

  let assert Ok(null_status_cards) = dict.get(board.groups, board.null_status)

  let group_keys = case null_status_cards {
    [_card, ..] -> board.group_keys
    [] -> list.filter(board.group_keys, fn(gk) { gk != board.null_status })
  }

  h.div(
    [attr.class("flex h-full")],
    list.map(group_keys, fn(status) {
      let assert Ok(cards) = dict.get(board.groups, status)

      let archive_all = case status {
        status if status == board.done_status ->
          h.a([event.on_click(UserClickedArchiveAllDone)], [
            h.text("archive all"),
          ])
        _ -> element.none()
      }

      h.div(
        [attr.class("min-w-80 max-w-80 mr-4 h-full")],
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
                  Ok(UserDraggedCardOverTarget(ev, card))
                })

              _ -> attr.none()
            }

            h.div(
              [
                attr.class("bg-(--background-secondary) mb-2 p-4 rounded-md"),
                attr.attribute("draggable", "true"),
                event.on("dragstart", fn(ev) {
                  Ok(UserStartedDraggingCard(ev, card))
                }),
                event.on("dragend", fn(ev) { Ok(UserStoppedDraggingCard(ev)) }),
                dragover,
              ],
              [
                h.div([attr.class(invisible)], [
                  element.map(
                    internal_link.view(internal_link.Model(
                      obs: model.obs,
                      page: page,
                      view_name: model.obs.view_name,
                    )),
                    InternalLinkMsg,
                  ),
                  task_info,
                  content_preview,
                  h.div([attr.class("flex justify-end")], [
                    h.a(
                      [
                        event.on_click(UserClickedEditInNeoVim(page)),
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
                  event.on("dragover", fn(_ev) {
                    Ok(UserDraggedCardOverColumn(status))
                  }),
                ],
                [],
              ),
            ]),
        ),
      )
    }),
  )
}
