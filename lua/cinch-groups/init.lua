-- cinch-groups: load strategies several plugins share, written once. It rides cinch's
-- bus: Collect spreads group tables into specs, Collected gives each plugin its group's
-- strategy. cinch registers what comes out as if you had written it on every spec.
-- Nothing of cinch is required at the top: setup() may run before cinch is installed.

local M = {}

local CINCH = 'https://github.com/techdeus88/cinch.nvim'

local started = false

--- Start listening. cinch calls this as the `groups` extension, with `extensions.groups`.
---@param groups? table<string, cinch.Group>
function M.start(groups)
  if started then
    return
  end
  local events = require('cinch.events')
  if not (events.names.Collect and events.names.Collected) then
    error('cinch-groups needs a cinch with the Collect and Collected events', 0)
  end
  started = true
  local assign, expand = require('cinch-groups.assign'), require('cinch-groups.expand')
  -- A spec's `group` is ours: cinch keeps it in data and does not warn.
  require('cinch.spec').field('group', { trigger = false })
  -- Before the groups: a group's fields are checked against the triggers cinch knows.
  require('cinch-groups.triggers').register()
  require('cinch-groups.registry').from_setup(groups or {}, 'setup()')
  events.on('Collect', function(d)
    d.value = expand.expand(d.value, d.origin, d.root)
  end)
  events.on('Collected', function(d)
    d.entries = assign.assign(d.entries)
  end)
  -- Features load before extensions, so the window is there to add to, if it is on.
  local ui = package.loaded['cinch.features.ui']
  if ui and ui.add_view then
    require('cinch-groups.ui').setup(ui)
  end
end

--- cinch with groups, from one bootstrap line: installs cinch when it is missing, then
--- calls its setup() with `groups` as the `groups` extension's options.
---@param opts? cinch.Opts|{ groups?: table<string, cinch.Group> }
function M.setup(opts)
  opts = vim.tbl_extend('force', {}, opts or {})
  if not pcall(require, 'cinch') then
    if vim.uv.fs_stat(vim.fn.stdpath('data') .. '/site/pack/core/opt/cinch.nvim') then
      vim.cmd.packadd('cinch.nvim')
    else
      vim.pack.add({ CINCH }, { confirm = false })
    end
  end
  opts.extensions = vim.tbl_extend('force', {}, opts.extensions or {})
  opts.extensions.groups = opts.groups or opts.extensions.groups or {}
  opts.groups = nil
  require('cinch').setup(opts)
end

--- The group a plugin is in, or nil.
---@param name string
---@return string?
function M.of(name)
  return require('cinch-groups.assign').member[name]
end

--- The names of the plugins in a group, in the order cinch registered them.
---@param group string
---@return string[]
function M.members(group)
  local member = require('cinch-groups.assign').member
  local out = {}
  for _, p in ipairs(require('cinch.state').list) do
    if member[p.name] == group then
      out[#out + 1] = p.name
    end
  end
  return out
end

--- Every group's strategy, by name: a copy.
---@return table<string, table>
function M.groups()
  return vim.deepcopy(require('cinch-groups.registry').groups)
end

--- Load every plugin of a group now, whatever it was waiting for.
---@param group string
---@param reason? string
function M.load(group, reason)
  if not require('cinch-groups.registry').groups[group] then
    return require('cinch.events').report(('no group named `%s`'):format(group), vim.log.levels.WARN)
  end
  require('cinch').load(M.members(group), reason or ('group ' .. group))
end

--- Load every plugin whose `on` trigger names `name`, now or whenever one arms later.
---@param name string
function M.fire(name)
  require('cinch-groups.triggers.on').fire(name)
end

--- :checkhealth cinch, under the `groups` extension.
function M.health()
  local h = vim.health
  local names = vim.tbl_keys(require('cinch-groups.registry').groups)
  table.sort(names)
  if #names == 0 then
    return h.info('no groups defined')
  end
  for _, name in ipairs(names) do
    local n = #M.members(name)
    if n == 0 then
      h.warn(('group `%s` has no plugins'):format(name))
    else
      h.ok(('group `%s`: %d plugin%s'):format(name, n, n == 1 and '' or 's'))
    end
  end
end

return M
