import { App, Modal } from "obsidian";

type ModalCallback = (modal: LustreModal, content_el: HTMLElement) => void;

export function open(
  app: App,
  on_open: ModalCallback,
  on_close: ModalCallback,
): LustreModal {
  let modal = new LustreModal(app, on_open, on_close);
  modal.open();
  return modal;
}

export function close(modal: LustreModal) {
  modal.close();
}

export class LustreModal extends Modal {
  on_open: ModalCallback;
  on_close: ModalCallback;

  constructor(app: App, on_open: ModalCallback, on_close: ModalCallback) {
    super(app);
    this.on_open = on_open;
    this.on_close = on_close;
  }

  onOpen() {
    this.on_open(this, this.contentEl);
  }

  onClose() {
    this.on_close(this, this.contentEl);
  }
}
