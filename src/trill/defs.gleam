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
import trill/board_view
import trill/toolbar

pub const view_name = "trill"

pub type Model {
  Model(
    obs: ObsidianContext,
    toolbar: Option(toolbar.Model),
    board_view: Option(board_view.Model),
    modal: Option(Modal),
  )
}

pub type Msg {
  ToolbarMsg(toolbar.Msg)
  BoardViewMsg(board_view.Msg)

  UserSubmittedNewBoardConfigForm(event: Dynamic)
  UserSubmittedEditBoardConfigForm(event: Dynamic)
  UserClickedDeleteBoardConfigCancel
  UserClickedDeleteBoardConfigConfirm

  ObsidianReportedFileChange
}
