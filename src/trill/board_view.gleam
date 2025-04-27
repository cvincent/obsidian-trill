import board.{type Board, type Card, Board, Card, TargetPlaceholder}
import board_config.{type BoardConfig, BoardConfig}
import card_filter
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
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string
import icons
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html as h
import lustre/event
import lustre/internals/vdom.{type Element}
import obsidian_context.{type ObsidianContext} as obs
import plinth/browser/element as pelement
import plinth/browser/event as pevent
import plinth/javascript/console
import tempo
import trill/internal_link
import util.{guard_element, option_guard}

pub type Model {
  Model(
    obs: ObsidianContext,
    board_config: BoardConfig,
    board: Board(String, Page),
    card_contents: Dict(String, String),
  )
}

pub fn new(obs: ObsidianContext, board_config: BoardConfig) {
  let #(board, effect) = new_board_from_config(board_config)
  #(Model(obs:, board_config:, board:, card_contents: dict.new()), effect)
}

pub fn update_board_config(
  board_view: Model,
  board_config: BoardConfig,
  force_refresh: Bool,
) {
  let #(board, effect) = case
    force_refresh || board_view.board_config.query != board_config.query
  {
    True -> new_board_from_config(board_config)
    False -> update_board_from_config(board_view.board, board_config)
  }

  #(Model(..board_view, board_config:, board:), effect)
}

fn new_board_from_config(
  board_config: BoardConfig,
) -> #(Board(String, Page), Effect(Msg)) {
  #(
    board.new_board(
      group_keys: list.map(board_config.columns, fn(c) { c.status }),
      cards: [],
      group_key_fn: group_key_fn,
      update_group_key_fn: update_group_key_fn,
      null_status: board_config.null_status,
      done_status: board_config.done_status,
    ),
    effect.from(fn(dispatch) {
      let pages = dataview.pages(board_config.query)
      dispatch(DataviewLoadedPages(pages))
    }),
  )
}

fn update_board_from_config(
  board: Board(String, Page),
  board_config: BoardConfig,
) {
  #(
    Board(
      ..board,
      group_keys: list.map(board_config.columns, fn(c) { c.status }),
      group_key_fn: group_key_fn,
      update_group_key_fn: update_group_key_fn,
      null_status: board_config.null_status,
      done_status: board_config.done_status,
    ),
    effect.none(),
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
  DataviewLoadedPages(pages: List(Page))

  InternalLinkMsg(internal_link.Msg)

  UserStartedDraggingCard(event: Dynamic, card: Card(Page))
  UserStoppedDraggingCard(event: Dynamic)
  UserDraggedCardOverTarget(event: Dynamic, over: Card(Page))
  UserDraggedCardOverColumn(over: String)
  UserClickedToggleTag(file: Page, tag: String)
  UserClickedEditInNeoVim(file: Page)
  UserClickedDebug(file: Page)
  UserClickedArchiveAllDone

  ObsidianReadPageContents(contents: Dict(String, String))
}

type Update =
  #(Model, Effect(Msg))

pub fn update(model: Model, msg: Msg) -> Update {
  case msg {
    DataviewLoadedPages(pages:) -> {
      #(
        Model(..model, board: board.set_cards(model.board, pages)),
        effect.from(fn(dispatch) {
          pages
          |> list.filter_map(fn(page) {
            use <- bool.guard(
              dict.has_key(model.card_contents, page.path),
              Error(Nil),
            )
            use file <- result.map(vault.get_file_by_path(
              model.obs.vault,
              page.path,
            ))

            vault.cached_read(model.obs.vault, file)
            |> promise.map(fn(content) { #(page.path, content) })
            |> Ok()
          })
          |> result.values()
          |> promise.await_list()
          |> promise.map(fn(contents) {
            dispatch(ObsidianReadPageContents(dict.from_list(contents)))
          })
          Nil
        }),
      )
    }

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

    UserDraggedCardOverTarget(ev, over_card) -> {
      {
        use ev <- result.try(pevent.cast_event(ev) |> result.replace_error(Nil))
        use target_card_el <- result.try(
          ev
          |> pevent.target()
          |> pelement.cast()
          |> result.replace_error(Nil),
        )
        use target_card_el <- result.try(pelement.closest(
          target_card_el,
          "[draggable=true]",
        ))

        let target = pxelement.get_bounding_client_rect(target_card_el)
        let mouse = pxevent.get_client_coords(ev)

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

    UserClickedToggleTag(file, tag) -> #(
      model,
      effect.from(fn(dispatch) {
        case file.tags |> list.contains(tag) {
          True -> obs.remove_tag(model.obs, file.path, tag)
          False -> obs.add_tag(model.obs, file.path, tag)
        }
      }),
    )

    UserClickedArchiveAllDone -> {
      let effect =
        effect.from(fn(_) {
          model.board.groups
          |> dict.get(model.board.done_status)
          |> result.unwrap([])
          |> list.each(fn(card) {
            obs.add_tag(model.obs, card.inner.path, "archive")
            card.inner
          })
        })

      #(model, effect)
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

    UserClickedDebug(page) -> #(model, effect.from(fn(_) { console.log(page) }))

    ObsidianReadPageContents(contents) -> {
      #(
        Model(..model, card_contents: dict.merge(model.card_contents, contents)),
        effect.none(),
      )
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
    use <- bool.guard(!result.is_ok(new_status), effect.none())
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
  div(
    "flex h-full px-4",
    list.map(statuses_to_show(model), fn(status) {
      let cards =
        dict.get(model.board.groups, status)
        |> result.unwrap([])

      div(
        "min-w-80 max-w-80 mr-4 h-full",
        list.append(
          [
            div("flex gap-2 mb-2", [
              div("", [h.text(status)]),
              div("", [
                guard_element(
                  status == model.board.done_status,
                  archive_all_link(),
                ),
              ]),
            ]),
          ],
          cards
            |> list.filter_map(card_view(model, _))
            |> list.append([
              h.div(
                [
                  attr.class("h-full"),
                  event_on("dragover", UserDraggedCardOverColumn(status)),
                ],
                [],
              ),
            ]),
        ),
      )
    }),
  )
}

fn card_view(model: Model, card: Card(Page)) {
  let page = card.inner

  use <- bool.guard(
    !card_filter.match(model.board_config.filter, page),
    Error(Nil),
  )

  let invisible = case card {
    Card(_) -> attr.none()
    _ -> attr.class("invisible")
  }

  let dragover = case card {
    TargetPlaceholder(_) -> attr.none()
    _ ->
      event.on("dragover", fn(ev) { Ok(UserDraggedCardOverTarget(ev, card)) })
  }

  let today = list.contains(page.tags, "today")
  let this_week = list.contains(page.tags, "this-week")

  h.div(
    [
      attr.class("bg-(--background-secondary) mb-2 p-4 rounded-md cursor-grab"),
      attr.attribute("draggable", "true"),
      event.on("dragstart", fn(ev) { Ok(UserStartedDraggingCard(ev, card)) }),
      event.on("dragend", fn(ev) { Ok(UserStoppedDraggingCard(ev)) }),
      dragover,
    ],
    [
      h.div([invisible], [
        element.map(
          internal_link.view(internal_link.Model(
            obs: model.obs,
            page: page,
            view_name: model.obs.view_name,
          )),
          InternalLinkMsg,
        ),
        tags(card),
        task_info(card),
        content_preview(model.card_contents, card),
        div("flex justify-between mt-2", [
          div("flex gap-1", [
            h.label([attr.class("flex gap-1 items-center cursor-pointer")], [
              h.div(
                [
                  attr.class("checkbox-container"),
                  attr.classes([#("is-enabled", today)]),
                ],
                [
                  h.input([
                    attr.type_("checkbox"),
                    attr.checked(today),
                    event.on_click(UserClickedToggleTag(page, "today")),
                  ]),
                ],
              ),
              h.text("today"),
            ]),
            h.label([attr.class("flex gap-1 items-center cursor-pointer")], [
              h.div(
                [
                  attr.class("checkbox-container"),
                  attr.classes([#("is-enabled", this_week)]),
                ],
                [
                  h.input([
                    attr.type_("checkbox"),
                    attr.checked(this_week),
                    event.on_click(UserClickedToggleTag(page, "this-week")),
                  ]),
                ],
              ),
              h.text("this-week"),
            ]),
          ]),
          div("flex items-center", [
            h.a(
              [
                event.on_click(UserClickedEditInNeoVim(page)),
                attr.class("text-xs"),
              ],
              [h.text("nvim")],
            ),
            h.a(
              [
                event.on_click(UserClickedDebug(page)),
                attr.class("text-xs ml-1"),
              ],
              [h.text("debug")],
            ),
          ]),
        ]),
      ]),
    ],
  )
  |> Ok()
}

fn div(classes: String, contents: List(Element(Msg))) {
  h.div([attr.class(classes)], contents)
}

fn event_on(event_name: String, msg: Msg) {
  event.on(event_name, fn(_ev) { Ok(msg) })
}

fn statuses_to_show(model: Model) {
  model.board_config.columns
  |> list.filter(fn(c) {
    {
      use <- bool.guard(!c.hide_if_empty, Ok(True))
      use group <- result.try(dict.get(model.board.groups, c.status))
      list.first(group) |> result.replace(True)
    }
    |> result.unwrap(False)
  })
  |> list.map(fn(c) { c.status })
}

fn archive_all_link() {
  h.a([event.on_click(UserClickedArchiveAllDone)], [h.text("archive all")])
}

fn tags(card: Card(Page)) {
  decode.run(
    dynamic.from(card.inner),
    decode.at(["original", "tags"], decode.list(decode.string)),
  )
  |> result.replace_error(element.none())
  |> result.map(fn(tags) {
    guard_element(
      list.length(tags) > 0,
      div(
        "flex flex-wrap gap-1 text-xs my-1",
        tags
          |> list.sort(string.compare)
          |> list.map(fn(tag) {
            div(
              "bg-(--background-secondary-alt) whitespace-nowrap rounded-full px-2",
              [h.text(tag)],
            )
          }),
      ),
    )
  })
  |> result.unwrap_both()
}

fn task_info(card: Card(Page)) {
  let tasks =
    decode.run(
      dynamic.from(card.inner),
      decode.at(["original", "file", "tasks"], decode.list(decode.dynamic)),
    )

  let task_count =
    result.try(tasks, fn(tasks) { Ok(list.length(tasks)) })
    |> result.unwrap(0)

  let done_count =
    result.try(tasks, fn(tasks) {
      list.count(tasks, fn(task) {
        Ok("x") == decode.run(task, decode.at(["status"], decode.string))
      })
      |> Ok()
    })
    |> result.unwrap(0)

  let task_info_color = case task_count - done_count {
    0 -> attr.class("text-(color:--text-muted)")
    _ -> attr.none()
  }

  guard_element(
    task_count > 0,
    h.div([attr.class("flex gap-1"), task_info_color], [
      div("[--icon-size:var(--icon-s)] mt-[1px]", [icons.icon("square-check")]),
      div("align-middle", [
        h.text(int.to_string(done_count) <> "/" <> int.to_string(task_count)),
      ]),
    ]),
  )
}

fn content_preview(card_contents: Dict(String, String), card: Card(Page)) {
  {
    use content <- result.try(dict.get(card_contents, card.inner.path))
    use re <- result.try(
      regexp.from_string("\\n# .+\\n") |> result.replace_error(Nil),
    )

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
        |> Ok()
      _ -> Error(Nil)
    }
  }
  |> result.unwrap(element.none())
}
