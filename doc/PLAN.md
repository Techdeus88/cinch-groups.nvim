# cinch-groups: concept and plan

## Status (2026-11-25)

Done, with tests on cinch's runner:
- **Core seams:** `Collect`, `Collected` and `spec.field(name, { trigger = false })` are in cinch (`247813c`); `doc/core-seams.patch` is history now.
- **Hookup:** cinch's `extensions` option (installs, adopts and loads an extension before specs), with `require('cinch-groups').setup()` for a single bootstrap line. The old `features = { 'groups' }` route still works.
- **Triggers:** `follows`, `delay`, `idle`, `visible`, `focus`, `root`, `path`, `lsp`, `mode`, `bt`, `on`, plus the `together` group field.
- **Window:** the group chip, the `group`/`took` pane lines and `/group:`; the Groups tab before Triggers; `<C-g>` to list Plugins by group. cinch's ui has `add_view`, `add_key`, `add_hint`, `add_chip`, `add_pane_lines`, `add_filter` and `add_grouping` for it.

Still open: the questions at the end of this file. Health checks are in (`:checkhealth cinch`, under extensions).

## Where it comes from

The `groups` branch of cinch (commit 23366c3) built groups into core: about 190 lines in `spec.lua`, a `groups` option in `init.lua`, three fields on the plugin record in `state.lua`, and the README and help sections. It works, but every rule of groups became a rule of cinch's spec resolution, and the branch has since drifted from `main` (`main` reads spec files from `stdpath('config')` only and now merges trigger lists).

This library keeps the branch's behavior and moves it out of core. cinch gets three small, general hooks. Groups is the first thing built on them.

## The concept

cinch has two ways to extend it already:

- **Features**: `features = { ... }` requires `cinch.features.<name>` and calls its `setup(opts[name])` before any spec is read. Nothing stops another plugin from shipping a module under that path.
- **The bus**: `events.on()` subscribers run in priority order and may change the payload.

What was missing is a point where an extension can see specs before they become plugin records. Groups only needs that. It is a rewrite of specs: once a plugin's group fields are copied onto its spec, cinch's normal resolution does the rest.

So a cinch extension is:

1. A plugin that ships `lua/cinch/features/<name>.lua`, returning a table with `setup(opts)`.
2. Optional fields of its own, made known with `spec.field(name, { trigger = false })`.
3. Bus subscribers, including the two spec hooks below.

## Core seams (doc/core-seams.patch)

| Seam | Where | What it allows |
| --- | --- | --- |
| `Collect { value, origin, root? }` | `spec.push()`, before a value is split into specs | Replace what a spec file, inline root or `add()` gave. `root` is set only for a spec file, so an extension can tell a file from inline specs. Groups spreads group tables here, and names a file's group after the file |
| `Collected { entries, origin }` | end of `spec.collect()`, before `register()` | See every entry of one read at once, and rewrite, add or drop them. Groups assigns members and copies strategy here |
| `spec.field(name, { trigger = false })` | `spec.lua` | A field cinch keeps in `data` without warning, and that is not a trigger |

All three are no-ops with nothing listening: the emits sit behind `events.has()`. cinch's full suite passes with the patch, and so does this library's case.

The patch applies to `main` as it is in your working tree, uncommitted changes included. It is not applied to your checkout.

## How the library works

```
setup() ── load_features ── groups.setup(opts.groups) ── registry.from_setup()
   │                                    └── on Collect, on Collected
   └── spec.collect()
         ├─ per file/root: Collect ── expand.expand(): group tables -> specs, wrapper marked
         └─ end of read: Collected ── assign.assign(): membership, then strategy copied onto the first spec
   └── spec.register() ── cinch's own resolution, unchanged
```

| File | Role |
| --- | --- |
| `lua/cinch/features/groups.lua` | The feature entry. Returns the library |
| `lua/cinch-groups/init.lua` | `setup`, and the API: `of`, `members`, `groups`, `load` |
| `lua/cinch-groups/registry.lua` | Group definitions, `plugins` lists, `dir` folders |
| `lua/cinch-groups/expand.lua` | Collect: spread group tables, mark wrapped specs (weak table keyed by the spec copy) |
| `lua/cinch-groups/assign.lua` | Collected: pick each plugin's group, copy the fields its specs leave unset |
| `tests/cases/groups.lua` | The branch's case, ported. Runs on cinch's runner |

## Differences from the branch

- Membership and strategy are worked out per read (one `collect()` call), not per plugin record. A spec added later with `add()` that names no group doesn't pick one up from an earlier read; cinch merges it into the record as usual.
- The group field stays in `p.data.group`. The plugin record gets no `group`, `group_wrap` or `group_dir`; `groups.of(name)` answers instead.
- When a group's `load` overrides a plugin's triggers, the warning is cinch's own, which says the spec "sets load". The branch said the plugin "is in group `git` with load = `now`". See open questions.
- `origin.index` counts the spread list, not the position inside the group table.

## File groups and order (beyond the branch)

- Every spec file's top-level table is a group. With no `group`, the file's name without `.lua` names it. This group ranks last, after `dir`, so `plugins` lists and `dir` folders still claim plugins from a plain list file.
- `order` (number, default 100) on any group: `assign` sorts the entries of one read by their group's order, keeping read order between equals. cinch registers, and so loads, in that order: `handler.lua`'s `ordered()` and the `now` and `later` passes all follow `state.list`. No core change was needed.

## Phases

1. **Spec groups (this skeleton, working).** Group tables, file groups, `order`, `setup()` groups with `plugins` and `dir`, precedence, warnings, `of`, `members`, `groups`, `load`. Case passes.
2. **Land the seams in cinch.** Apply `doc/core-seams.patch`, add a `Collect`/`Collected` case to cinch's suite (rewrite, drop and add an entry), document both events in the README's event table and `doc/cinch.txt`. Drop the `groups` branch.
3. **Group actions.** `:Cinch group load|update|disable <name>` as a subcommand. Needs a seam for subcommands (`usercmd`), so features can register one.
4. **Groups in the window.** Group name on each row, or a Groups section on the Plugins view, through the `ui` feature. Needs a seam for rows or sections. Every new wording goes past you first.
5. **Health.** `:checkhealth cinch-groups`: empty groups, unknown fields, a `dir` that matches no file.

## Open questions

1. **The warning text.** For the branch's wording, cinch's `resolve_load()` needs to know the `load` came from somewhere else. Either a `data.load_from` note it reads, or a `Resolve` event. Worth it?
2. **Nested deps with their own `group`.** They never become entries, so `group = 'x'` on a nested dep does nothing. The branch did the same. Keep it, or walk `deps` in `assign`?
3. **Feature namespace.** Shipping `lua/cinch/features/groups.lua` from another repo works today but puts a file in cinch's namespace. An alternative is letting `features` take a full module path, such as `'cinch-groups'`.
4. **Bootstrapping.** Extensions must be on the runtimepath before `setup()`. Should cinch's `self` handling cover a list of extensions too, so one bootstrap installs and updates them all?
5. **File group names.** The base name collides across folders (`lsp/init.lua` and `ui/init.lua` are both `init`). Use the path under the root (`lsp/init`), or the folder name for an `init.lua`?
6. **Order across reads.** `order` sorts within one read. A plugin from a later `add()` with order 1 still registers after everything `setup()` read. Fine, or should cinch's `ordered()` sort by a field instead of `state.list` position?
7. **Repo.** This folder isn't a git repo yet. Init it, publish it as `techdeus88/cinch-groups.nvim`, or keep it in cinch as `extras/`?
