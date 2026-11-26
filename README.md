# cinch-groups.nvim

Load strategies several [cinch](https://github.com/techdeus88/cinch.nvim) plugins share, written once.

A group is a `load` and any triggers: cinch's own (`event`, `ft`, `cmd`, `keys`), the twelve this library adds (see [Triggers](#triggers)), or one of yours. Each plugin in the group takes them, and anything the plugin sets itself wins.

```lua
-- lua/plugins/git.lua
return {
  group = 'git',
  event = 'BufReadPost',
  { 'lewis6991/gitsigns.nvim', opts = {} },            -- loads on BufReadPost
  { 'sindrets/diffview.nvim', cmd = 'DiffviewOpen' },  -- on BufReadPost or :DiffviewOpen
}
```

Every spec file is a group: the table it returns. With no `group`, the file's name names it, so this is the group `editor`, and its plugins load before groups with a higher `order`:

```lua
-- lua/plugins/editor.lua
return {
  event = 'InsertEnter',
  order = 10,
  { 'windwp/nvim-autopairs', opts = {} },
  'kylechui/nvim-surround',
}
```

`order` is a number, default 100. Lower loads first among plugins that load at the same moment: the `now` pass, the `later` queue, or one event. It sorts the specs of one read, which is every file of `setup()` or one `add()` call. A plugin's dependencies still load before it.

It is a cinch extension, which lives outside cinch. cinch's core never learns what a group is: this library listens to two events on cinch's bus and rewrites specs before cinch registers them.

`BufReadPre` is an early moment to load a whole group: a plugin whose `setup()` touches open buffers or windows can make Neovim refuse the file being read (E201). `BufReadPost` is the safer event for groups.

## Install

Either way, cinch installs cinch-groups if it's missing, then keeps it updated as one of your plugins.

**As a cinch extension.** Keep your cinch bootstrap, and name `groups` under `extensions`, with the groups of `setup()` as its options:

```lua
require('cinch').setup({
  extensions = {
    groups = {
      git = { event = 'BufReadPost' },                              -- specs with group = 'git'
      ui  = { event = 'UIEnter', plugins = { 'lualine.nvim' } },    -- by plugin name
      lsp = { ft = { 'lua', 'python' }, dir = 'lsp' },              -- every file under lua/plugins/lsp/
    },
  },
})
```

**In one bootstrap line.** Bootstrap cinch-groups instead of cinch, and call its `setup()` with cinch's options and `groups`. It installs cinch when it's missing, then calls `require('cinch').setup()`:

```lua
vim.pack.add({ 'https://github.com/techdeus88/cinch-groups.nvim' })
require('cinch-groups').setup({
  spec = { 'plugins' },
  groups = { git = { event = 'BufReadPost' } },
})
```

The older way, `features = { ..., 'groups' }` with `groups = { ... }` in cinch's `setup()`, still works when cinch-groups is already on the runtimepath.

It needs a cinch with extensions and the `Collect` and `Collected` events.

## Who is in a group

A plugin is in at most one group. The first of these that applies wins:

1. Its spec says `group = 'name'`. `group = false` keeps it out of every group.
2. A group table wraps its spec.
3. A group in `setup()` lists it in `plugins`.
4. A group in `setup()` has a `dir` that holds its spec file. `dir = true` is a folder with the group's name.
5. The file it is in, when that file's table names no group. The group takes the file's name without `.lua`: `lua/plugins/lsp/servers.lua` is `servers`. Two files with one name are one group.

Inline specs in `setup()` and specs given to `add()` have no file group.

A spec nested in another plugin's `deps` is in no group because of where it is nested.

## Triggers

Each is a field on a plugin's spec or on a group, which gives it to every plugin in the group. Several triggers on one plugin: whichever comes first loads it. A plugin that loads in the middle of an event still sees that event for its buffer.

| Field | Value | Loads when |
| --- | --- | --- |
| `follows` | group or plugin name(s) | that group or plugin has finished loading. A group has finished when none of its plugins waits or loads |
| `delay` | ms | that long after the UI is up |
| `idle` | ms | no key has been pressed for that long, after the UI is up. Every key starts the wait again |
| `visible` | `true` | the editor is on screen: after the UI is up and its first frame is drawn |
| `focus` | `true` | you come back to Neovim: the first `FocusGained` after a `FocusLost` |
| `root` | marker(s): `'Cargo.toml'`, `{ '.git', 'go.mod' }` | a file opens in a folder with one of these above it |
| `path` | glob(s): `'*.http'`, `'~/notes/**'` | a file whose path matches opens. No slash: the file's name. From `/` or `~`: the whole path, symlinks resolved. Otherwise: the end of the path |
| `lsp` | server name(s), or `true` for any | that language server attaches |
| `mode` | mode letter(s): `'i'`, `'v'`, `'t'` | you first enter that mode. `'v'` is any visual mode, `'s'` any select mode |
| `bt` | buftype(s): `'terminal'`, `'quickfix'` | a buffer of that `'buftype'` shows in a window |
| `on` | name(s) | your code calls `require('cinch-groups').fire(name)`. A name fired before a plugin waits on it stays fired |

`together = true` is a group field, not a trigger: whatever loads one plugin of the group loads the rest with it.

```lua
return {
  group = 'rust',
  root = 'Cargo.toml',
  together = true,
  { 'mrcjkb/rustaceanvim' },
  { 'saecki/crates.nvim', follows = 'lsp' },  -- its own trigger beside the group's
}
```

A value of the wrong type is reported and ignored.

## What a plugin takes from its group

Each field of the group the plugin's own specs don't set. Its own `event` replaces the group's `event`, `event = false` drops it, and its own `cmd` sits beside the group's `event`.

A group's `load` counts as explicit: a group with `load = 'later'` loads its plugins later and their triggers are ignored. A plugin with its own `load` other than `'trigger'` takes none of the group's triggers.

One name is one group. Defined in `setup()` and in files, its fields merge in the order cinch reads them, `setup()` first, the later one winning.

## In the window

With cinch's `ui` feature on:

- **Plugins:** each row has a chip with its group, and the pane has a `group` line (the group, and how the plugin joined it) and a `took` line (what it took from the group). `/group:git` shows one group. `<C-g>` lists the plugins by group instead of by state; `working` and Updates keep their sections.
- **Groups:** a tab before Triggers, one row per group in `order`. Each row shows a light (● all loaded, ◐ some, ○ none), the order, load time, strategy, and how many have loaded. The pane shows its order, strategy, where it's defined, and each plugin with how it joined. `<CR>` opens a group to its plugins, `l` loads it, and `u` asks to update its plugins that have updates, on their rows in Plugins.

An icon of your own goes in cinch's `ui = { icons = { group = '...' } }`.

## API

```lua
local groups = require('cinch-groups')
groups.of('gitsigns.nvim')  -- 'git'
groups.members('git')       -- { 'gitsigns.nvim', 'diffview.nvim' }
groups.groups()             -- every group's strategy, by name
groups.load('git')          -- load the whole group now
groups.fire('Notes')        -- load what waits on `on = 'Notes'`
require('cinch').extensions.groups  -- the same table
```

## Tests

The cases run on cinch's own runner. From a cinch checkout:

```bash
for f in ../cinch-groups.nvim/tests/cases/*.lua; do cp "$f" "tests/cases/zzg_$(basename "$f")"; done
```

```bash
CINCH_GROUPS_ROOT=../cinch-groups.nvim nvim -l tests/run.lua zzg_
```
