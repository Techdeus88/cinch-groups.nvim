-- The triggers cinch-groups adds to cinch. Each is a cinch trigger, so it works on a
-- plugin's spec, and on a group, which gives it to every plugin in the group.

local M = {}

M.names = { 'follows', 'delay', 'root', 'lsp', 'visible', 'idle', 'mode', 'bt', 'path', 'on', 'focus' }

--- Register every trigger with cinch, before any spec is read.
function M.register()
  local cinch = require('cinch')
  for _, name in ipairs(M.names) do
    cinch.trigger(name, require('cinch-groups.triggers.' .. name))
  end
  require('cinch-groups.triggers.together').start()
end

return M
