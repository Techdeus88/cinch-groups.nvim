-- lsp = 'rust_analyzer' or { 'gopls', 'lua_ls' }, or true for any: load when that
-- language server attaches to a buffer. One attached already when it is armed counts too.

local util = require('cinch-groups.triggers.util')

local M = {}

---@param names (string|true)[]
---@param client? vim.lsp.Client
---@return string? the value that matched
local function match(names, client)
  if not client then
    return
  elseif vim.list_contains(names, true) then
    return 'true'
  end
  return vim.list_contains(names, client.name) and client.name or nil
end

function M.parse(v)
  return util.values('lsp', v, function(x)
    return x == true or (type(x) == 'string' and x ~= '')
  end, 'a language server name, or true')
end

function M.arm(p, names)
  for _, client in ipairs(vim.lsp.get_clients()) do
    local m = match(names, client)
    if m then
      return vim.schedule(function()
        util.fire(p, 'lsp ' .. m)
      end)
    end
  end
  util.autocmd(p, 'LspAttach', {
    callback = function(args)
      local m = match(names, vim.lsp.get_client_by_id(args.data.client_id))
      if m then
        util.load_in(p, 'lsp ' .. m, args)
      end
    end,
  })
end

M.disarm = util.clear

return M
