-- visible = true: load once the editor is on screen, after the UI is up and its first
-- frame is drawn, so that frame never waits on these plugins.

local util = require('cinch-groups.triggers.util')

local M = {}

local drawn = false
---@type cinch.Plugin[]
local queue = {}

local function drain()
  local list = queue
  queue = {}
  for _, p in ipairs(list) do
    util.fire(p, 'visible true')
  end
end

local waiting = false

function M.parse(v)
  return util.values('visible', v, function(x)
    return x == true
  end, 'true')
end

function M.arm(p)
  queue[#queue + 1] = p
  if drawn then
    return vim.schedule(drain)
  elseif waiting then
    return
  end
  waiting = true
  util.after_ui(function()
    -- The next tick, after a redraw: what is on screen is the first frame.
    vim.schedule(function()
      vim.cmd.redraw()
      drawn = true
      vim.schedule(drain)
    end)
  end)
end

function M.disarm(p)
  queue = vim.tbl_filter(function(q)
    return q ~= p
  end, queue)
end

return M
