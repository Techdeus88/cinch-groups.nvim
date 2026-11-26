-- focus = true: load when you come back to Neovim, the first FocusGained after a
-- FocusLost. The FocusGained a terminal sends at startup does not count.

local util = require('cinch-groups.triggers.util')

local M = {}

local left = false
local watching = false

local function watch()
  if watching then
    return
  end
  watching = true
  vim.api.nvim_create_autocmd('FocusLost', {
    desc = 'cinch-groups: focus left',
    callback = function()
      left = true
    end,
  })
end

function M.parse(v)
  return util.values('focus', v, function(x)
    return x == true
  end, 'true')
end

function M.arm(p)
  watch()
  util.autocmd(p, 'FocusGained', {
    callback = function(args)
      if left then
        util.load_in(p, 'focus true', args)
      end
    end,
  })
end

M.disarm = util.clear

return M
