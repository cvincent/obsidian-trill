import { ItemView, Scope, WorkspaceLeaf } from "obsidian";

export class LustreView extends ItemView {
  view_type: string;
  get_display_text: (view: LustreView) => string;
  on_open: (view: LustreView) => void;
  on_close: (view: LustreView) => void;

  constructor(
    leaf: WorkspaceLeaf,
    view_type: string,
    get_display_text: (view: LustreView) => string,
    on_open: (view: LustreView) => void,
    on_close: (view: LustreView) => void,
  ) {
    super(leaf);
    this.view_type = view_type;
    this.get_display_text = get_display_text;
    this.on_open = on_open;
    this.on_close = on_close;
    this.navigation = true;
  }

  getViewType(): string {
    return this.view_type;
  }

  getDisplayText(): string {
    return this.get_display_text(this);
  }

  async onOpen() {
    this.on_open(this);
  }

  async onClose() {
    this.on_close(this);
  }
}

export function container_el(view: LustreView) {
  return view.containerEl;
}

export function container_el_content(view: LustreView) {
  return view.containerEl.children[1];
}
