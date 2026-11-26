-- What the triggers share: firing a plugin, the autocmds each armed plugin owns, and
-- loading in the middle of an event so the plugin still sees that event for its buffer.

local M = {}

---@type table<string, integer[]> plugin name -> the autocmds its triggers made
local aus = {}

--- Load `p` now, the way its own trigger would; `reason` reads `<trigger> <value>`.
---@param p cinch.Plugin
---@param reason string
---@param done? fun()
function M.fire(p, reason, done)
  if p.state == 'pending' then
    require('cinch.handler').fire(p, reason, done)
  elseif done then
    done()
  end
end

--- An autocmd that belongs to `p`, removed by clear(p).
---@param p cinch.Plugin
---@param event string|string[]
---@param opts vim.api.keyset.create_autocmd
function M.autocmd(p, event, opts)
  opts.desc = opts.desc or ('cinch-groups: load ' .. p.name)
  aus[p.name] = aus[p.name] or {}
  table.insert(aus[p.name], vim.api.nvim_create_autocmd(event, opts))
end

---@param p cinch.Plugin
function M.clear(p)
  for _, id in ipairs(aus[p.name] or {}) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
  aus[p.name] = nil
end

--- Load `p` while `args.event` runs, then run what it added for that event and for each
--- of `also`, so it sees the buffer that fired it. FileType gets the buffer's filetype.
---@param p cinch.Plugin
---@param reason string
---@param args vim.api.keyset.create_autocmd.callback_args
---@param also? string[]
function M.load_in(p, reason, args, also)
  local handler = require('cinch.handler')
  local list = vim.list_extend({ args.event }, also or {})
  local seen = {}
  for _, ev in ipairs(list) do
    seen[ev] = handler.seen(ev)
  end
  M.fire(p, reason, function()
    for _, ev in ipairs(list) do
      local a = args
      if ev ~= args.event then
        local ft = vim.api.nvim_buf_is_valid(args.buf) and vim.bo[args.buf].filetype or ''
        a = { buf = args.buf, event = ev, match = ev == 'FileType' and ft or args.match, file = args.file }
      end
      handler.replay(ev, a, seen[ev])
    end
  end)
end

--- `v` as a list, each item checked by `ok`; what fails is reported and dropped.
---@param name string the trigger
---@param v any
---@param ok fun(x: any): boolean
---@param want string what a value should be, for the warning
---@return any[]
function M.values(name, v, ok, want)
  local list = type(v) == 'table' and v or { v }
  local out = {}
  for _, x in ipairs(list) do
    if ok(x) then
      out[#out + 1] = x
    else
      local msg = '`%s = %s`: each value should be %s; it is ignored'
      require('cinch.events').report(msg:format(name, vim.inspect(x), want), vim.log.levels.WARN)
    end
  end
  return out
end

--- Run `fn` once Neovim's UI is up: on UIEnter, or VimEnter when no UI is coming.
---@param fn fun()
function M.after_ui(fn)
  if vim.v.vim_did_enter == 1 then
    return fn()
  end
  local event = require('cinch').ui_coming() and 'UIEnter' or 'VimEnter'
  vim.api.nvim_create_autocmd(event, { once = true, callback = fn })
end

return M
