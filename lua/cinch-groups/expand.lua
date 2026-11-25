-- Collect: a group table, `{ group = 'git', event = ..., { spec }, { spec } }`, becomes
-- its specs, each one marked with the group that wraps it. cinch then reads a plain list.

local registry = require('cinch-groups.registry')

local M = {}

---@type table<table, string> spec table -> the group table that wrapped it
M.wrapped = setmetatable({}, { __mode = 'k' })

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

---@param list table
---@param group? string the group table that wraps `list`
---@param where string
---@param out table
local function walk(list, group, where, out)
  for _, s in ipairs(list) do
    if is_group(s) then
      registry.define(s.group, s, where)
      walk(s, s.group, where, out)
    elseif group and (type(s) == 'string' or type(s) == 'table') then
      -- A copy to mark, so a spec table you share is not marked for every place it is in.
      local own = type(s) == 'string' and { s } or vim.tbl_extend('force', {}, s)
      M.wrapped[own] = group
      out[#out + 1] = own
    else
      out[#out + 1] = s
    end
  end
end

--- The Collect payload's value with every group table spread into its specs.
---@param value any
---@param origin cinch.Origin
---@return any
function M.expand(value, origin)
  if type(value) ~= 'table' or is_single(value) or not holds_group(value) then
    return value
  end
  local out = {}
  walk(is_group(value) and { value } or value, nil, origin.file, out)
  return out
end

return M
