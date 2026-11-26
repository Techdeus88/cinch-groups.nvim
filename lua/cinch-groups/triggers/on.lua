-- on = 'Notes': load when your code calls require('cinch-groups').fire('Notes'). A name
-- fired before a plugin waits on it stays fired, so the order of the two does not matter.

local util = require('cinch-groups.triggers.util')

local M = {}

---@type table<string, table<string, cinch.Plugin>> name -> plugins waiting on it
local waiting = {}
---@type table<string, true>
local fired = {}

--- Load every plugin waiting on `name`, in declaration order.
---@param name string
function M.fire(name)
  fired[name] = true
  local set = waiting[name] or {}
  waiting[name] = nil
  for _, p in ipairs(require('cinch.state').list) do
    if set[p.name] then
      util.fire(p, 'on ' .. name)
    end
  end
end

function M.parse(v)
  return util.values('on', v, function(x)
    return type(x) == 'string' and x ~= ''
  end, 'a name')
end

function M.arm(p, names)
  for _, name in ipairs(names) do
    if fired[name] then
      return vim.schedule(function()
        util.fire(p, 'on ' .. name)
      end)
    end
  end
  for _, name in ipairs(names) do
    waiting[name] = waiting[name] or {}
    waiting[name][p.name] = p
  end
end

function M.disarm(p, names)
  for _, name in ipairs(names) do
    if waiting[name] then
      waiting[name][p.name] = nil
    end
  end
end

return M
