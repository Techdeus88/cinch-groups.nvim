-- follows = 'lsp' or { 'colors', 'nvim-tree.lua' }: load once that group or plugin has
-- finished loading. A group has finished when none of its plugins waits or loads.

local util = require('cinch-groups.triggers.util')

local M = {}

---@type table<string, table<string, cinch.Plugin>> target -> plugins waiting on it
local waiting = {}
local listening = false

local busy = { registered = true, pending = true, loading = true }

---@param target string
---@return boolean
local function finished(target)
  local state = require('cinch.state')
  local p = state.plugins[target]
  if p then
    return p.state == 'loaded'
  end
  local members = require('cinch-groups').members(target)
  for _, name in ipairs(members) do
    if busy[state.plugins[name].state] then
      return false
    end
  end
  return #members > 0
end

---@param target string
local function check(target)
  local set = waiting[target]
  if not set or not finished(target) then
    return
  end
  waiting[target] = nil
  -- In declaration order, as cinch loads the plugins of one trigger.
  for _, p in ipairs(require('cinch.state').list) do
    if set[p.name] then
      util.fire(p, 'follows ' .. target)
    end
  end
end

local function listen()
  if listening then
    return
  end
  listening = true
  require('cinch.events').on('Load', function(d)
    local name = d.plugin.name
    -- After the load that finished it, not in the middle of it.
    vim.schedule(function()
      check(name)
      local group = require('cinch-groups').of(name)
      if group then
        check(group)
      end
    end)
  end)
end

function M.parse(v)
  return util.values('follows', v, function(x)
    return type(x) == 'string' and x ~= ''
  end, 'a group or plugin name')
end

function M.arm(p, targets)
  listen()
  for _, target in ipairs(targets) do
    waiting[target] = waiting[target] or {}
    waiting[target][p.name] = p
    -- What it follows may have loaded already.
    vim.schedule(function()
      check(target)
    end)
  end
end

function M.disarm(p, targets)
  for _, target in ipairs(targets) do
    if waiting[target] then
      waiting[target][p.name] = nil
    end
  end
end

return M
