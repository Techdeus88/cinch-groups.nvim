-- idle = 2000: load once no key has been pressed for that many ms, after the UI is up.
-- Every key starts the wait again; nothing listens once nothing waits.

local util = require('cinch-groups.triggers.util')

local M = {}

local ns = vim.api.nvim_create_namespace('cinch-groups.idle')

---@class cinch_groups.Idle
---@field p cinch.Plugin
---@field ms integer
---@field timer uv.uv_timer_t

---@type table<string, cinch_groups.Idle[]>
local armed = {}
local listening = false

---@param w cinch_groups.Idle
local function start(w)
  w.timer:stop()
  w.timer:start(
    w.ms,
    0,
    vim.schedule_wrap(function()
      util.fire(w.p, 'idle ' .. w.ms)
    end)
  )
end

local function listen()
  if listening then
    return
  end
  listening = true
  vim.on_key(function()
    for _, list in pairs(armed) do
      for _, w in ipairs(list) do
        start(w)
      end
    end
  end, ns)
end

function M.parse(v)
  return util.values('idle', v, function(x)
    return type(x) == 'number' and x > 0
  end, 'a number of ms')
end

function M.arm(p, values)
  util.after_ui(function()
    if p.state ~= 'pending' then
      return
    end
    armed[p.name] = {}
    for _, ms in ipairs(values) do
      local w = { p = p, ms = ms, timer = assert(vim.uv.new_timer()) }
      table.insert(armed[p.name], w)
      start(w)
    end
    listen()
  end)
end

function M.disarm(p)
  for _, w in ipairs(armed[p.name] or {}) do
    w.timer:stop()
    w.timer:close()
  end
  armed[p.name] = nil
  if listening and next(armed) == nil then
    vim.on_key(nil, ns)
    listening = false
  end
end

return M
