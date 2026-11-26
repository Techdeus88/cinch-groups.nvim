-- Collect: a group table, `{ group = 'git', event = ..., { spec }, { spec } }`, becomes
-- its specs, each one marked with the group that wraps it. A spec file's top-level table
-- is a group too: with no `group`, the file's name names it. cinch then reads a plain list.

local registry = require('cinch-groups.registry')

local M = {}

---@type table<table, string> spec table -> the group table that wrapped it
M.wrapped = setmetatable({}, { __mode = 'k' })
---@type table<table, string> spec table -> the group named after its file, which had no `group`
M.filed = setmetatable({}, { __mode = 'k' })

--- One spec, as cinch's push() tells them apart from a list.
---@param v any
---@return boolean
local function is_single(v)
  return type(v) == 'string' or v.src ~= nil or (type(v[1]) == 'string' and v[2] == nil)
end

---@param v any
---@return boolean
local function is_group(v)
  return type(v) == 'table' and type(v.group) == 'string' and not is_single(v)
end

--- Whether one spec says its group itself: `group` at the top or in `data`, false too.
---@param v string|table
---@return boolean
local function names_group(v)
  return type(v) == 'table' and (v.group ~= nil or (type(v.data) == 'table' and v.data.group ~= nil))
end

---@param v any
---@return boolean
local function holds_group(v)
  if is_group(v) then
    return true
  end
  for _, s in ipairs(v) do
    if is_group(s) then
      return true
    end
  end
  return false
end

--- A copy of a spec to mark, so a spec table you share is not marked everywhere it is.
---@param s string|table
---@return table
local function copy(s)
  return type(s) == 'string' and { s } or vim.tbl_extend('force', {}, s)
end

---@param list table
---@param group? string
---@param marks table<table, string> which kind of membership `group` is
---@param where string
---@param out table
local function walk(list, group, marks, where, out)
  for _, s in ipairs(list) do
    if is_group(s) then
      registry.define(s.group, s, where)
      walk(s, s.group, M.wrapped, where, out)
    elseif group and (type(s) == 'string' or type(s) == 'table') then
      local own = copy(s)
      marks[own] = group
      out[#out + 1] = own
    else
      out[#out + 1] = s
    end
  end
end

--- The Collect payload's value with every group table spread into its specs. `root` is
--- set when the value is a whole spec file: its top-level table is then a group.
---@param value any
---@param origin cinch.Origin
---@param root? string
---@return any
function M.expand(value, origin, root)
  if type(value) ~= 'table' and type(value) ~= 'string' then
    return value
  end
  local out = {}
  if root and not is_group(value) then
    local name = vim.fn.fnamemodify(origin.file, ':t:r')
    if type(value) == 'table' and not is_single(value) then
      registry.define(name, value, origin.file)
    elseif names_group(value) then
      -- One spec naming its own group: that one, not one named after the file.
      return value
    else
      registry.define(name, {}, origin.file)
      value = { value }
    end
    walk(value, name, M.filed, origin.file, out)
    return out
  end
  if type(value) == 'string' or is_single(value) or not holds_group(value) then
    return value
  end
  walk(is_group(value) and { value } or value, nil, M.wrapped, origin.file, out)
  return out
end

return M
