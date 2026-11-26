-- mode = 'i' or { 'v', 't' }: load the first time you enter that mode. 'v' is any visual
-- mode (v, V, CTRL-V), 's' any select mode; the rest are the first letter of mode().

local util = require('cinch-groups.triggers.util')

local M = {}

--- The mode a mode() string is in, as this trigger names them.
---@param m string
---@return string
local function kind(m)
  local c = m:sub(1, 1)
  if c == 'V' or c == '\22' then
    return 'v'
  elseif c == 'S' or c == '\19' then
    return 's'
  end
  return c
end

function M.parse(v)
  return util.values('mode', v, function(x)
    return type(x) == 'string' and #x == 1
  end, "one mode letter, like 'i' or 'v'")
end

function M.arm(p, modes)
  if vim.list_contains(modes, kind(vim.api.nvim_get_mode().mode)) then
    return vim.schedule(function()
      util.fire(p, 'mode ' .. kind(vim.api.nvim_get_mode().mode))
    end)
  end
  util.autocmd(p, 'ModeChanged', {
    callback = function(args)
      local m = kind(vim.v.event.new_mode)
      if vim.list_contains(modes, m) then
        util.load_in(p, 'mode ' .. m, args)
      end
    end,
  })
end

M.disarm = util.clear

return M
