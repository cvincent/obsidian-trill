import ffi/obsidian/html_element.{type HTMLElement}

pub type MarkdownPostProcessorContext

pub type MarkdownSectionInfo {
  MarkdownSectionInfo(text: String, line_start: Int, line_end: Int)
}

// pub type MarkdownPostProcessorContext {
//   MarkdownPostProcessor(
//     doc_id: String,
//     // frontmatter: yaml // We'll want probably Glaml and its types for this
//     source_path: String
//   )
// }

@external(javascript, "src/ffi/obsidian/markdown_post_processor_context.ts", "add_child")
pub fn add_child(
  ctx: MarkdownPostProcessorContext,
  el: HTMLElement,
) -> HTMLElement

@external(javascript, "src/ffi/obsidian/markdown_post_processor_context.ts", "get_section_info")
pub fn get_section_info(
  ctx: MarkdownPostProcessorContext,
  el: HTMLElement,
) -> Result(MarkdownSectionInfo, Nil)
