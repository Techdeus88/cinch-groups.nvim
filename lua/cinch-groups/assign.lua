-- Collected: put each plugin in one group and give it the group's strategy, field by
-- field, before cinch registers anything. Every spec of one read is in view here, so a
-- field any of a plugin's specs sets keeps the group's value out.

local events = require('cinch.events')
local expand = require('cinch-groups.expand')
local registry = require('cinch-groups.registry')
local spec = require('cinch.spec')

local M = {}

---@type table<string, string> plugin name -> its group
M.member = {}

---@class cinch_groups.Item
---@field e cinch.Entry
---@field data table its normalized data, read only

---@param msg string
local function warn(msg)
  events.report(msg, vim.log.levels.WARN)
end

--- The group a plugin is in: the one its spec names, else the one that wraps it, lists
--- it or holds its file. `group = false` leaves it out.
---@param name string
---@param items cinch_groups.Item[]
---@return string?
local function group_of(name, items)
  local own
  for _, it in ipairs(items) do
    if it.data.group ~= nil then
      own = it.data.group
    end
  end
  if own == false then
    return
  elseif own ~= nil then
    if registry.groups[own] then
      return own
    end
    warn(('`%s` names group `%s`, which nothing defines; it is ignored'):format(name, tostring(own)))
  end
  local wrap
  for _, it in ipairs(items) do
    local g = expand.wrapped[it.e.spec]
    if g and wrap and g ~= wrap then
      warn(('%s: `%s` is already in group `%s`; `%s` is ignored'):format(it.e.origin.file, name, wrap, g))
    end
    wrap = wrap or g
  end
  return wrap or registry.listed[name] or registry.dir_group(items[1].e.origin.file)
end

--- Put the group's fields nobody set on the plugin's first spec. A spec whose own `load`
--- is not 'trigger' takes none of the group's triggers, which it would ignore.
---@param items cinch_groups.Item[]
---@param group string
local function share(items, group)
  local own_load
  for _, it in ipairs(items) do
    own_load = it.data.load ~= nil and it.data.load or own_load
  end
  local first = items[1].e
  local copy
  for k, v in pairs(registry.groups[group]) do
    local set = vim.iter(items):any(function(it)
      return it.data[k] ~= nil
    end)
    local wanted = k == 'load' or own_load == nil or own_load == 'trigger'
    if not set and wanted then
      copy = copy or (type(first.spec) == 'string' and { first.spec } or vim.tbl_extend('force', {}, first.spec))
      copy[k] = type(v) == 'table' and vim.deepcopy(v) or v
    end
  end
  if copy then
    first.spec = copy
  end
end

--- The Collected payload's entries, each plugin given its group's strategy.
---@param entries cinch.Entry[]
---@return cinch.Entry[]
function M.assign(entries)
  ---@type table<string, cinch_groups.Item[]>
  local by_name, order = {}, {}
  for _, e in ipairs(entries) do
    local n = spec.normalize(e.spec)
    local name = n and spec.name(n)
    if name and name ~= '' then
      if not by_name[name] then
        by_name[name], order[#order + 1] = {}, name
      end
      table.insert(by_name[name], { e = e, data = n.data })
    end
  end
  for _, name in ipairs(order) do
    local group = group_of(name, by_name[name])
    M.member[name] = group or M.member[name]
    if group then
      share(by_name[name], group)
    end
  end
  return entries
end

return M
