import ffi/console
import ffi/event
import ffi/obsidian/file.{type File}
import ffi/obsidian/html_element.{type Event, type HTMLElement}
import ffi/obsidian/markdown_post_processor_context.{type MarkdownSectionInfo}
import ffi/obsidian/menu
import ffi/obsidian/plugin.{type Plugin}
import ffi/obsidian/vault
import ffi/obsidian/workspace
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import task

pub type TestCustom {
  TestCustom(key1: String, key2: Int)
}

pub fn main(plugin: Plugin) {
  plugin.register_markdown_post_processor(plugin, fn(el, ctx) {
    case markdown_post_processor_context.get_section_info(ctx, el) {
      Ok(section_info) -> add_section_info_attrs(plugin, el, section_info)
      Error(Nil) -> Nil
    }
  })
}

fn add_section_info_attrs(
  plugin: Plugin,
  el: HTMLElement,
  section_info: MarkdownSectionInfo,
) {
  html_element.find_all(el, ".task-list-item-checkbox")
  |> list.index_map(fn(el, i) {
    html_element.set_attr(
      el,
      "data-section-start-line",
      int.to_string(section_info.line_start),
    )

    html_element.set_attr(
      el,
      "data-section-end-line",
      int.to_string(section_info.line_end),
    )

    html_element.set_attr(el, "data-index", int.to_string(i))

    let line =
      Ok(el)
      |> result.try(html_element.match_parent(_, "[data-line]"))
      |> result.try(html_element.get_attr(_, "data-line"))

    case line {
      Ok(line) -> html_element.set_attr(el, "data-section-line", line)
      Error(Nil) -> Nil
    }

    html_element.on_click_event(el, fn(el, ev) {
      checkbox_clicked(plugin, el, ev)
    })
  })

  Nil
}

fn checkbox_clicked(plugin: Plugin, el: HTMLElement, ev: Event) {
  event.stop_propagation(ev.js_event)

  case ev.which {
    1 -> toggle_checkbox(plugin, el)
    3 -> show_checkbox_menu(plugin, el, ev)
    _ -> Nil
  }

  Nil
}

fn toggle_checkbox(plugin: Plugin, el: HTMLElement) {
  let checked = html_element.get_checked(el)

  let new_state = case checked {
    True -> " "
    False -> "x"
  }

  set_checkbox(plugin, el, new_state)
}

fn show_checkbox_menu(plugin: Plugin, el: HTMLElement, ev: Event) {
  let menu = menu.new_menu()
  menu.add_item(menu, "Pending", fn() { set_checkbox(plugin, el, "-") })
  menu.add_item(menu, "Canceled", fn() { set_checkbox(plugin, el, "_") })
  menu.show_at_mouse_event(menu, ev.js_event)
  Nil
}

fn set_checkbox(plugin: Plugin, el: HTMLElement, new_state: String) {
  let vault = plugin.get_vault(plugin)

  case get_file_and_line(plugin, el) {
    Ok(#(file, section_start_line, section_end_line, section_line)) -> {
      vault.process(vault, file, fn(data) {
        let lines = string.split(data, "\n")

        let #(before_section, rest) = list.split(lines, section_start_line)
        let #(section, after_section) =
          list.split(rest, section_end_line - section_start_line + 1)

        let section =
          section
          |> string.join("\n")
          |> task.parse()
          |> task.mark(section_line, new_state)
          |> task.to_markdown()
          |> string.split("\n")

        before_section
        |> list.append(section)
        |> list.append(after_section)
        |> string.join("\n")
      })
    }
    _ -> Nil
  }
}

fn get_file_and_line(plugin, el) -> Result(#(File, Int, Int, Int), Nil) {
  let section_start_line =
    el
    |> html_element.get_attr("data-section-start-line")
    |> result.try(int.parse)

  let section_end_line =
    el
    |> html_element.get_attr("data-section-end-line")
    |> result.try(int.parse)

  let section_line =
    el
    |> html_element.get_attr("data-section-line")
    |> result.try(int.parse)

  let file =
    plugin
    |> plugin.get_workspace()
    |> workspace.get_active_file()

  case section_start_line, section_end_line, section_line, file {
    Ok(section_start_line), Ok(section_end_line), Ok(section_line), Ok(file) ->
      Ok(#(file, section_start_line, section_end_line, section_line))
    _, _, _, _ -> Error(Nil)
  }
}

pub fn set_checkbox_at_path_line(
  plugin: Plugin,
  path: String,
  line: Int,
  new_state: String,
) {
  let vault = plugin.get_vault(plugin)
  let assert Ok(file) = vault.get_file_by_path(vault, path)
  let line = line - 1

  vault.process(vault, file, fn(data) {
    let lines = string.split(data, "\n")

    let #(before, after) = list.split(lines, line)

    let #(before, before_section) =
      before
      |> list.reverse()
      |> list.split_while(fn(line) { string.trim(line) != "" })

    let before = list.reverse(before)
    let before_section = list.reverse(before_section)

    let section_start_line = line - list.length(before)
    let section_line = line - section_start_line

    let #(after, after_section) =
      after
      |> list.split_while(fn(line) { string.trim(line) != "" })

    let section =
      list.append(before, after)
      |> string.join("\n")
      |> task.parse()
      |> task.mark(section_line, new_state)
      |> task.to_markdown()
      |> string.split("\n")

    let ret =
      before_section
      |> list.append(section)
      |> list.append(after_section)
      |> string.join("\n")

    console.log(ret)
    ret
  })
}
