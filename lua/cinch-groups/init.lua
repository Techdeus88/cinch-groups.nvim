-- cinch-groups: load strategies several plugins share, written once. It rides cinch's
-- bus: Collect spreads group tables into specs, Collected gives each plugin its group's
-- strategy. cinch registers what comes out as if you had written it on every spec.

local assign = require('cinch-groups.assign')
local events = require('cinch.events')
local expand = require('cinch-groups.expand')
local registry = require('cinch-groups.registry')
local spec = require('cinch.spec')

local M = {}

local started = false

--- Start listening. cinch calls this as the `groups` feature, with `opts.groups`.
---@param groups? table<string, cinch.Group>
function M.setup(groups)
  if started then
    return
  end
  if not (events.names.Collect and events.names.Collected) then
    error('cinch-groups needs a cinch with the Collect and Collected events', 0)
  end
  started = true
  -- A spec's `group` is ours: cinch keeps it in data and does not warn.
  spec.field('group', { trigger = false })
  registry.from_setup(groups or {}, 'setup()')
  events.on('Collect', function(d)
    d.value = expand.expand(d.value, d.origin)
  end)
  events.on('Collected', function(d)
    d.entries = assign.assign(d.entries)
  end)
end

--- The group a plugin is in, or nil.
---@param name string
---@return string?
function M.of(name)
  return assign.member[name]
end

--- The names of the plugins in a group, in the order cinch registered them.
---@param group string
---@return string[]
function M.members(group)
  local out = {}
  for _, p in ipairs(require('cinch.state').list) do
    if assign.member[p.name] == group then
      out[#out + 1] = p.name
    end
  end
  return out
end

--- Every group's strategy, by name: a copy.
---@return table<string, table>
function M.groups()
  return vim.deepcopy(registry.groups)
end

--- Load every plugin of a group now, whatever it was waiting for.
---@param group string
---@param reason? string
function M.load(group, reason)
  if not registry.groups[group] then
    return events.report(('no group named `%s`'):format(group), vim.log.levels.WARN)
  end
  require('cinch').load(M.members(group), reason or ('group ' .. group))
end

return M
