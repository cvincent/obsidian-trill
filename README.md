# Obsidian Task Additions

Some additions to Obsidian's default handling of task checkboxes:

- Two additional states are introduced:
  - `[-]` for "pending"
  - `[_]` for "canceled"
  - These are adapted from what I was used to in my old Neorg setup.
  - These additional states can be set in preview mode via a right-click menu.
- Hierarchical states are handled automatically. Setting a parent checkbox sets
  its children accordingly. And parents are updated to reflect the state of
  their children automatically.
- Hard line wrap of 80 characters is respected and maintained, with two spaces
  for indentation.
- Dataview-style metadata fields are automatically maintained for "completed"
  and "canceled" states, e.g. `[completion:: timestamp]` or `[cancellation::
  timestamp]`.
- Works in iOS, but there is no right-click menu for the additional states, as I
  do not use them.
- `setCheckboxAtPathLine` is exposed for scriptability. I use a [hacky
  fork](https://github.com/cvincent/obsidian-local-rest-api) of the [Obsidian
  Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api)
  plugin to expose an `eval` endpoint I can call from NeoVim to do all sorts of
  things. For example, I have keymappings for manipulating task lists via this
  plugin, giving me a consistent editing experience whether I'm in Obsidian or
  NeoVim.

## Caveats

I developed this plugin for my own use, having first scoured the Obsidian
community plugins for some combination that did everything I wanted. Thus, the
plugin's features are very much designed for my (apparently) peculiar needs. No
additional configuration is provided, and none is likely to be added. I aim for
this to be "completed software" in terms of addressing my own specific needs in
developing it. That said, PRs are welcome if they would be useful to my own
setup, otherwise forks are also welcome.

Not satisfied with learning one new thing at a time, that being the Obsidian
plugin API, I also took this as a, opportunity to learn Gleam. So the plugin
itself is primarily Gleam code, with TypeScript limited to glue code providing
external function calls into the Obsidian API. I added the glue code as needed
for the project, so it's far from a complete Gleam interface into Obsidian, but
it would be a great place to start for any other weirdos like me interested in
making their lives harder (but more interesting) by developing their own
Obsidian plugins in Gleam.

## Developing

```sh
cd path/to/vault/.obsidian/plugins
git clone git@github.com:cvincent/obsidian-task-additions.git
npm install
gleam build && tsc -noEmit -skipLibCheck -outDir . && node esbuild.config.mjs production
```
