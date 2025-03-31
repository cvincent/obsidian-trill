import board.{type Board, type Card, Card}
import board_config
import ffi/dataview.{type Page, Page}
import ffi/obsidian/modal.{type Modal}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import gleam/result
import obsidian_context.{type ObsidianContext}
import plinth/browser/event.{type Event as PEvent}
import trill/internal_link
import trill/toolbar

pub const view_name = "trill"

pub type Model {
  Model(
    toolbar: Option(toolbar.Model),
    obsidian_context: ObsidianContext,
    board: Option(Board(String, Page)),
    modal: Option(Modal),
  )
}

pub type Msg {
  InternalLinkMsg(internal_link.Msg)
  ToolbarMsg(toolbar.Msg)

  UserStartedDraggingCard(event: Dynamic, card: Card(Page))
  UserStoppedDraggingCard(event: Dynamic)
  UserDraggedCardOverTarget(event: PEvent(Dynamic), over: Card(Page))
  UserDraggedCardOverColumn(event: PEvent(Dynamic), over: String)
  UserClickedEditInNeoVim(file: Page)
  UserClickedArchiveAllDone

  ObsidianReadPageContents(contents: Dict(String, String))

  UserSubmittedNewBoardConfigForm(event: Dynamic)
  UserSubmittedEditBoardConfigForm(event: Dynamic)

  UserClickedDeleteBoardConfigCancel
  UserClickedDeleteBoardConfigConfirm

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
