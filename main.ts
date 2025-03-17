import { Plugin } from 'obsidian';
import { main, set_checkbox_at_path_line } from "./build/dev/javascript/obsidian_plugin/main.mjs";

export default class MyPlugin extends Plugin {
  async onload() {
    main(this)
  }

  onunload() {
    // No-op
  }
}
