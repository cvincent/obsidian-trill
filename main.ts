import { Plugin } from 'obsidian';
import { main, set_checkbox_at_path_line } from "./build/dev/javascript/obsidian_plugin/main.mjs";

export default class MyPlugin extends Plugin {
  async onload() {
    main(this)
  }

  onunload() {
    // No-op
  }

  setCheckboxAtPathLine(path: string, line: number, new_state: string) {
    set_checkbox_at_path_line(this, path, line, new_state)
  }
}
