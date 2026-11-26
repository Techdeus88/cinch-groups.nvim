-- delay = 300: load that many ms after the UI is up, for soon but not at startup.

local util = require('cinch-groups.triggers.util')

local M = {}

---@type table<string, uv.uv_timer_t[]>
local timers = {}

function M.parse(v)
  return util.values('delay', v, function(x)
    return type(x) == 'number' and x >= 0
  end, 'a number of ms')
end

function M.arm(p, values)
  util.after_ui(function()
    if p.state ~= 'pending' then
      return
    end
    timers[p.name] = timers[p.name] or {}
    for _, ms in ipairs(values) do
      table.insert(
        timers[p.name],
        vim.defer_fn(function()
          util.fire(p, 'delay ' .. ms)
        end, ms)
      )
    end
  end)
end

function M.disarm(p)
  for _, t in ipairs(timers[p.name] or {}) do
    if not t:is_closing() then
      t:stop()
      t:close()
    end
  end
  timers[p.name] = nil
end

return M
