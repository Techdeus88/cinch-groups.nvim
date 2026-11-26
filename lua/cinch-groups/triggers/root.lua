-- root = 'Cargo.toml' or { '.git', 'go.mod' }: load when a file opens inside a folder
-- that has one of these. A buffer already open when it is armed counts too.

local util = require('cinch-groups.triggers.util')

local M = {}

--- The first marker found above the buffer's file.
---@param buf integer
---@param markers string[]
---@return string?
local function found(buf, markers)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' or vim.api.nvim_buf_get_name(buf) == '' then
    return
  end
  for _, m in ipairs(markers) do
    if vim.fs.root(buf, m) then
      return m
    end
  end
end

function M.parse(v)
  return util.values('root', v, function(x)
    return type(x) == 'string' and x ~= ''
  end, 'a file or folder name')
end

function M.arm(p, markers)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local m = vim.api.nvim_buf_is_loaded(buf) and found(buf, markers)
    if m then
      return vim.schedule(function()
        util.fire(p, 'root ' .. m)
      end)
    end
  end
  util.autocmd(p, { 'BufReadPost', 'BufNewFile' }, {
    callback = function(args)
      local m = found(args.buf, markers)
      if m then
        util.load_in(p, 'root ' .. m, args, { 'FileType' })
      end
    end,
  })
end

M.disarm = util.clear

return M
