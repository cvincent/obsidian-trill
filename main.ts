import { Plugin } from 'obsidian';
import { main } from "./build/dev/javascript/obsidian_plugin/main.mjs";

export default class Trill extends Plugin {
  async onload() {
    main(this)
  }

  onunload() {
    // No-op
  }
}
