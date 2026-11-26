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
---@alias cinch_groups.How 'own'|'wrap'|'listed'|'dir'|'file'|'dep'
---@type table<string, { how: cinch_groups.How, file?: string }> plugin name -> how it joined
M.how = {}
---@type table<string, table<string, any>> plugin name -> the fields it took from its group
M.took = {}

---@class cinch_groups.Item
---@field e cinch.Entry
---@field data table its normalized data, read only

-- The group of plugins seen only as another plugin's dependency.
M.DEPS = 'dependencies'

---@param msg string
local function warn(msg)
  events.report(msg, vim.log.levels.WARN)
end

--- A group by name, made empty when nothing defines it yet: naming one is enough.
---@param name string
---@param where? string the file that named it
local function ensure(name, where)
  if not registry.groups[name] then
    registry.define(name, {}, where)
  end
end

--- The group a plugin is in: the one its spec names, made if nothing else defines it,
--- else the one that wraps it, lists it or holds its file. `group = false` leaves it out.
---@param name string
---@param items cinch_groups.Item[]
---@return string? group
---@return { how: cinch_groups.How, file?: string }? how it joined
local function group_of(name, items)
  local own, named_in
  for _, it in ipairs(items) do
    if it.data.group ~= nil then
      own, named_in = it.data.group, it.e.origin.file
    end
  end
  if own == false then
    return
  elseif type(own) == 'string' and own ~= '' then
    ensure(own, named_in)
    return own, { how = 'own' }
  elseif own ~= nil then
    warn(('`%s` has group `%s`, not a name or false; it is ignored'):format(name, tostring(own)))
  end
  local wrap
  for _, it in ipairs(items) do
    local g = expand.wrapped[it.e.spec]
    if g and wrap and g ~= wrap then
      warn(('%s: `%s` is already in group `%s`; `%s` is ignored'):format(it.e.origin.file, name, wrap, g))
    end
    wrap = wrap or g
  end
  local filed
  for _, it in ipairs(items) do
    filed = filed or expand.filed[it.e.spec]
  end
  local file = items[1].e.origin.file
  if wrap then
    return wrap, { how = 'wrap' }
  elseif registry.listed[name] then
    return registry.listed[name], { how = 'listed' }
  end
  local dir = registry.dir_group(file)
  if dir then
    return dir, { how = 'dir', file = registry.dir_of[dir] }
  elseif filed then
    return filed, { how = 'file', file = vim.fs.basename(file) }
  end
end

--- Entries in group order, lower first; equal orders keep the order they were read in.
--- cinch registers in this order, and loads plugins that load at the same moment in it.
---@param entries cinch.Entry[]
---@param key table<cinch.Entry, number>
---@return cinch.Entry[]
local function by_order(entries, key)
  local at = {}
  for i, e in ipairs(entries) do
    at[e] = i
  end
  local sorted = vim.list_slice(entries)
  table.sort(sorted, function(a, b)
    local ka, kb = key[a] or registry.default_order, key[b] or registry.default_order
    if ka ~= kb then
      return ka < kb
    end
    return at[a] < at[b]
  end)
  return sorted
end

--- Put the group's fields nobody set on the plugin's first spec. A spec whose own `load`
--- is not 'trigger' takes none of the group's triggers, which it would ignore.
---@param items cinch_groups.Item[]
---@param group string
---@return table<string, any> took the fields it took
local function share(items, group)
  local own_load
  for _, it in ipairs(items) do
    own_load = it.data.load ~= nil and it.data.load or own_load
  end
  local first = items[1].e
  local copy
  local took = {}
  for k, v in pairs(registry.groups[group]) do
    local set = vim.iter(items):any(function(it)
      return it.data[k] ~= nil
    end)
    local wanted = k == 'load' or own_load == nil or own_load == 'trigger'
    if not set and wanted then
      copy = copy or (type(first.spec) == 'string' and { first.spec } or vim.tbl_extend('force', {}, first.spec))
      copy[k] = type(v) == 'table' and vim.deepcopy(v) or v
      took[k] = v
    end
  end
  if copy then
    first.spec = copy
  end
  return took
end

---@param d any
---@return boolean
local function is_ref(d)
  return type(d) == 'string' and not d:find('/') and not d:find(':')
end

--- Every spec nested in `deps`, at any depth, by name, in the order they are found.
---@param entries cinch.Entry[]
---@return table<string, { specs: vim.pack.Spec[], origin: cinch.Origin }>, string[]
local function nested(entries)
  local found, order = {}, {}
  local function walk(data, origin)
    for _, d in ipairs(data.deps or {}) do
      local n = not is_ref(d) and spec.normalize(d)
      local name = n and spec.name(n)
      if name and name ~= '' then
        if not found[name] then
          found[name], order[#order + 1] = { specs = {}, origin = origin }, name
        end
        table.insert(found[name].specs, n)
        walk(n.data, origin)
      end
    end
  end
  for _, e in ipairs(entries) do
    local n = spec.normalize(e.spec)
    if n then
      walk(n.data, e.origin)
    end
  end
  return found, order
end

--- Put each plugin seen only as a dependency in the group its own spec names, else the
--- one a setup() group lists it in, else `dependencies`. Where it is nested does not
--- count. A group with a strategy gets a spec of the plugin's own to carry it, added to
--- `entries`, since a nested spec has no place to.
---@param entries cinch.Entry[]
---@param by_name table<string, cinch_groups.Item[]>
---@param key table<cinch.Entry, number>
local function dependencies(entries, by_name, key)
  local state = require('cinch.state')
  local found, order = nested(entries)
  for _, name in ipairs(order) do
    local p = state.plugins[name]
    if not by_name[name] and not (p and not p.dep_only) then
      local own
      for _, n in ipairs(found[name].specs) do
        if n.data.group ~= nil then
          own = n.data.group
        end
      end
      local group, how
      if type(own) == 'string' and own ~= '' then
        ensure(own, found[name].origin.file)
        group, how = own, { how = 'own' }
      elseif own ~= false and registry.listed[name] then
        group, how = registry.listed[name], { how = 'listed' }
      elseif own ~= false then
        ensure(M.DEPS)
        group, how = M.DEPS, { how = 'dep' }
      end
      if group then
        M.member[name], M.how[name] = group, how
        local first = found[name].specs[1]
        local e = { spec = { src = first.src, name = first.name }, origin = found[name].origin }
        local items = { { e = e, data = {} } }
        for _, n in ipairs(found[name].specs) do
          items[#items + 1] = { e = e, data = n.data }
        end
        M.took[name] = share(items, group)
        if next(M.took[name]) then
          entries[#entries + 1] = e
          key[e] = registry.order[group]
        end
      end
    end
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
  local key = {}
  for _, name in ipairs(order) do
    local group, how = group_of(name, by_name[name])
    M.member[name] = group or M.member[name]
    if group then
      M.how[name] = how
      M.took[name] = share(by_name[name], group)
      for _, it in ipairs(by_name[name]) do
        key[it.e] = registry.order[group]
      end
    end
  end
  dependencies(entries, by_name, key)
  return by_order(entries, key)
end

return M
