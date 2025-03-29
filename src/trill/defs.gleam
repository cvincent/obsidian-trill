import board.{type Board, type Card, Card}
import board_config.{type BoardConfig, BoardConfig}
import ffi/dataview.{type Page, Page}
import ffi/obsidian/modal.{type Modal}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import obsidian_context.{type ObsidianContext}
import plinth/browser/event.{type Event as PEvent}

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
  UserClickedInternalLink(path: String)
  UserHoveredInternalLink(event: Dynamic, path: String)

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
