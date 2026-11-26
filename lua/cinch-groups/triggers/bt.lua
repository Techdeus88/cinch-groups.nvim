-- bt = 'terminal' or { 'quickfix', 'help' }: load when a buffer of that 'buftype' is
-- shown in a window. One on screen when it is armed counts too.

local util = require('cinch-groups.triggers.util')

local M = {}

function M.parse(v)
  return util.values('bt', v, function(x)
    return type(x) == 'string' and x ~= ''
  end, "a 'buftype', like 'terminal' or 'quickfix'")
end

function M.arm(p, types)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local bt = vim.bo[vim.api.nvim_win_get_buf(win)].buftype
    if vim.list_contains(types, bt) then
      return vim.schedule(function()
        util.fire(p, 'bt ' .. bt)
      end)
    end
  end
  util.autocmd(p, { 'BufWinEnter', 'TermOpen' }, {
    callback = function(args)
      local bt = vim.bo[args.buf].buftype
      if vim.list_contains(types, bt) then
        util.load_in(p, 'bt ' .. bt, args, { 'FileType' })
      end
    end,
  })
end

M.disarm = util.clear

return M
