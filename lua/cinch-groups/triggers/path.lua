-- path = '*.http' or { '~/notes/**', 'docs/**/*.md' }: load when a file whose path
-- matches opens. A glob with no slash matches the file's name, as an autocmd pattern
-- does; one starting with / or ~ the whole path; any other, the end of the path.

local util = require('cinch-groups.triggers.util')

local M = {}

---@type table<string, vim.lpeg.Pattern[]>
local compiled = {}

--- The patterns a glob compiles to. One from / or ~ also comes with its fixed folder
--- resolved: a buffer's name has symlinks resolved, so ~/notes -> iCloud still matches.
---@param glob string
---@return vim.lpeg.Pattern[]
local function patterns(glob)
  if compiled[glob] then
    return compiled[glob]
  end
  local list = {}
  if glob:find('^~') or glob:find('^/') then
    local g = vim.fs.normalize(glob)
    list[1] = vim.glob.to_lpeg(g)
    local dir = g:match('^([^*?%[{]*)/')
    local real = dir and vim.uv.fs_realpath(dir)
    if real and real ~= dir then
      list[2] = vim.glob.to_lpeg(real .. g:sub(#dir + 1))
    end
  else
    list[1] = vim.glob.to_lpeg(glob:find('/') and ('**/' .. glob) or glob)
  end
  compiled[glob] = list
  return list
end

---@param glob string
---@param file string
---@return boolean
local function matches(glob, file)
  local subject = glob:find('/') and file or vim.fs.basename(file)
  for _, pat in ipairs(patterns(glob)) do
    if pat:match(subject) then
      return true
    end
  end
  return false
end

---@param buf integer
---@param globs string[]
---@return string?
local function hit(buf, globs)
  local file = vim.api.nvim_buf_get_name(buf)
  if file == '' or vim.bo[buf].buftype ~= '' then
    return
  end
  file = vim.fs.normalize(file)
  for _, g in ipairs(globs) do
    if matches(g, file) then
      return g
    end
  end
end

function M.parse(v)
  return util.values('path', v, function(x)
    return type(x) == 'string' and x ~= ''
  end, 'a glob')
end

function M.arm(p, globs)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local g = vim.api.nvim_buf_is_loaded(buf) and hit(buf, globs)
    if g then
      return vim.schedule(function()
        util.fire(p, 'path ' .. g)
      end)
    end
  end
  util.autocmd(p, { 'BufReadPost', 'BufNewFile' }, {
    callback = function(args)
      local g = hit(args.buf, globs)
      if g then
        util.load_in(p, 'path ' .. g, args, { 'FileType' })
      end
    end,
  })
end

M.disarm = util.clear

return M
