# cinch-groups.nvim

Load strategies several [cinch](https://github.com/techdeus88/cinch.nvim) plugins share, written once.

A group is a `load` and any triggers (`event`, `ft`, `cmd`, `keys`, or a custom one). Each plugin in the group takes them, and anything the plugin sets itself wins.

```lua
-- lua/plugins/git.lua
return {
  group = 'git',
  event = 'BufReadPre',
  { 'lewis6991/gitsigns.nvim', opts = {} },            -- loads on BufReadPre
  { 'sindrets/diffview.nvim', cmd = 'DiffviewOpen' },  -- on BufReadPre or :DiffviewOpen
}
```

It is a cinch feature that lives outside cinch. cinch's core never learns what a group is: this library listens to two events on cinch's bus and rewrites specs before cinch registers them.

## Install

cinch reads your specs before it loads any plugin, so cinch-groups has to be on the runtimepath before `setup()`, the same way cinch is. Bootstrap both, then turn the feature on:

```lua
vim.pack.add({
  'https://github.com/techdeus88/cinch.nvim',
  'https://github.com/techdeus88/cinch-groups.nvim',
})

require('cinch').setup({
  features = { 'messages', 'stats', 'updates', 'ui', 'groups' },
  groups = {
    git = { event = 'BufReadPre' },                                 -- specs with group = 'git'
    ui  = { event = 'UIEnter', plugins = { 'lualine.nvim' } },      -- by plugin name
    lsp = { ft = { 'lua', 'python' }, dir = 'lsp' },                -- every file under lua/plugins/lsp/
  },
})
```

Add `{ 'techdeus88/cinch-groups.nvim' }` to a spec file too, so cinch updates it like any other plugin.

It needs a cinch with the `Collect` and `Collected` events. See [doc/core-seams.patch](doc/core-seams.patch).

## Who is in a group

A plugin is in at most one group. The first of these that applies wins:

1. Its spec says `group = 'name'`. `group = false` keeps it out of every group.
2. A group table wraps its spec.
3. A group in `setup()` lists it in `plugins`.
4. A group in `setup()` has a `dir` that holds its spec file. `dir = true` is a folder with the group's name.

A spec nested in another plugin's `deps` is in no group because of where it is nested.

## What a plugin takes from its group

Each field of the group the plugin's own specs don't set. Its own `event` replaces the group's `event`, `event = false` drops it, and its own `cmd` sits beside the group's `event`.

A group's `load` counts as explicit: a group with `load = 'later'` loads its plugins later and their triggers are ignored. A plugin with its own `load` other than `'trigger'` takes none of the group's triggers.

One name is one group. Defined in `setup()` and in files, its fields merge in the order cinch reads them, `setup()` first, the later one winning.

## API

```lua
local groups = require('cinch-groups')
groups.of('gitsigns.nvim')  -- 'git'
groups.members('git')       -- { 'gitsigns.nvim', 'diffview.nvim' }
groups.groups()             -- every group's strategy, by name
groups.load('git')          -- load the whole group now
```

## Tests

The case runs on cinch's own runner. From a cinch checkout that carries the seams:

```bash
cp ../cinch-groups.nvim/tests/cases/groups.lua tests/cases/
```

```bash
CINCH_GROUPS_ROOT=../cinch-groups.nvim nvim -l tests/run.lua groups
```
