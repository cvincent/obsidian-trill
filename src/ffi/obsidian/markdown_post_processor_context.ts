import { MarkdownPostProcessorContext } from "obsidian";
import { Result, Ok, Error } from "build/dev/javascript/prelude.mjs"
import { MarkdownSectionInfo } from "build/dev/javascript/obsidian_plugin/ffi/obsidian/markdown_post_processor_context.mjs"

export function add_child(ctx: MarkdownPostProcessorContext, el: any) {
  ctx.addChild(el)
}

export function get_section_info(ctx: MarkdownPostProcessorContext, el: any): Result<MarkdownSectionInfo, null> {
  let ret = ctx.getSectionInfo(el)
  if (!ret) return new Error(null)
  else return new Ok(new MarkdownSectionInfo(ret.text, ret.lineStart, ret.lineEnd))
}
