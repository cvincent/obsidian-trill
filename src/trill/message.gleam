import board.{type Card, Card}
import board_config.{type BoardConfig, BoardConfig}
import ffi/dataview.{type Page, Page}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import plinth/browser/event.{type Event as PEvent}

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
