import board.{type Board, type Card, Card}
import board_config.{type BoardConfig, BoardConfig}
import ffi/dataview.{type Page, Page}
import ffi/obsidian/modal.{type Modal}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import gleam/result
import obsidian_context.{type ObsidianContext}
import plinth/browser/event.{type Event as PEvent}
import trill/internal_link

pub const view_name = "trill"

pub type Model {
  Model(
    obsidian_context: ObsidianContext,
    board_config: Option(BoardConfig),
    board_configs: List(BoardConfig),
    board: Option(Board(String, Page)),
    modal: Option(Modal),
  )
}

pub type Msg {
  InternalLinks(internal_link.Msg)

  UserStartedDraggingCard(event: Dynamic, card: Card(Page))
  UserStoppedDraggingCard(event: Dynamic)
  UserDraggedCardOverTarget(event: PEvent(Dynamic), over: Card(Page))
  UserDraggedCardOverColumn(event: PEvent(Dynamic), over: String)
  UserClickedEditInNeoVim(file: Page)
  UserClickedArchiveAllDone

  UserSelectedBoardConfig(board_config: BoardConfig)
  ObsidianReadPageContents(contents: Dict(String, String))

  UserClickedBoardMenu(event: Dynamic)
  UserClickedNewBoard
  UserClickedDuplicateBoard
  UserClickedEditBoard
  UserClickedDeleteBoard

  UserSubmittedNewBoardForm(event: Dynamic)
  UserSubmittedEditBoardForm(event: Dynamic)

  UserClickedDeleteBoardCancel
  UserClickedDeleteBoardConfirm

  ObsidianReportedFileChange
}

pub fn group_key_fn(page: Page) {
  result.unwrap(page.status, board_config.null_status)
}

pub fn update_group_key_fn(page: Page, new_status: String) {
  let status = case new_status {
    s if s == board_config.null_status -> Error(board_config.null_status)
    s -> Ok(s)
  }
  Page(..page, status:)
}
