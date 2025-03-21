import { TFile, PaneType, Workspace, WorkspaceLeaf } from "obsidian";
import { Result, Ok, Error, List } from "build/dev/javascript/prelude.mjs"

export function get_active_file(workspace: Workspace): Result<TFile, null> {
  let file = workspace.getActiveFile()
  if (file) return new Ok(file)
  else return new Error(null)
}

export function get_leaves_of_type(workspace: Workspace, view_type: string): List<WorkspaceLeaf> {
  return List.fromArray(workspace.getLeavesOfType(view_type))
}

export function get_leaf(workspace: Workspace, pane_type: PaneType): WorkspaceLeaf {
  return workspace.getLeaf(pane_type)
}

export async function leaf_set_view_state(leaf: WorkspaceLeaf, view_type: string, active: boolean) {
  await leaf.setViewState({ type: view_type, active: active })
}

export function reveal_leaf(workspace: Workspace, leaf: WorkspaceLeaf): void {
  workspace.revealLeaf(leaf)
}

export function open_link_text(workspace: Workspace, path: string, pane_type: PaneType): void {
  workspace.openLinkText(path, path, pane_type)
}

export function trigger_hover_link(
  workspace: Workspace,
  event: any,
  view_name: string,
  path: string,
): void {
  workspace.trigger("hover-link", {
    event: event,
    source: view_name,
    hoverParent: event.target,
    targetEl: event.target,
    linktext: path,
  })
}
