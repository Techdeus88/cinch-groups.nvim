-- together = true, on a group: whatever loads one of its plugins loads the rest with it.
-- A group field, not a trigger: its plugins do not get it.

local M = {}

local listening = false

function M.start()
  if listening then
    return
  end
  listening = true
  require('cinch.events').on('Load', function(d)
    local groups = require('cinch-groups')
    local name = d.plugin.name
    local group = groups.of(name)
    if not (group and require('cinch-groups.registry').together[group]) then
      return
    end
    -- After the load that started it, so its own replay comes first.
    vim.schedule(function()
      local state = require('cinch.state')
      local rest = vim.tbl_filter(function(n)
        return state.plugins[n].state == 'pending'
      end, groups.members(group))
      if #rest > 0 then
        require('cinch').load(rest, ('together %s with %s'):format(group, name))
      end
    end)
  end)
end

return M
