-- Groups by name: each one's load strategy, and who setup() says is in it. One name is
-- one group wherever it is defined: setup() first, then spec files in the order cinch
-- reads them, later fields winning.

local events = require('cinch.events')
local spec = require('cinch.spec')

local M = {}

local loads = { now = true, later = true, now_if_args = true, trigger = true }

---A load strategy plugins share. In setup() it can also say who is in it.
---@class cinch.Group
---@field load? cinch.Load
---@field event? string|string[]
---@field ft? string|string[]
---@field cmd? string|string[]
---@field keys? string|(string|cinch.Key)[]
---@field order? number lower loads first, among plugins that load at the same moment; default 100
---@field together? boolean one plugin of the group loading loads the rest with it
---@field plugins? string[] setup() only: plugin names in it
---@field dir? string|true setup() only: a folder under a spec root whose files are in it; true: its name

---@type table<string, table<string, any>> group -> its `load` and triggers
M.groups = {}
--- Where a plugin with no group, or in a group with no `order`, loads among the groups.
M.default_order = 100
---@type table<string, number> group -> its `order`: lower loads first
M.order = {}
---@type table<string, true> groups that load whole: one plugin loading brings the rest
M.together = {}
---@type table<string, string> plugin name -> the setup() group whose `plugins` lists it
M.listed = {}
---@type { dir: string, group: string }[] folders whose spec files are in a group, as `/lsp/`
M.dirs = {}
---@type table<string, string> group -> its `dir`, as written: `lsp/`
M.dir_of = {}
---@type table<string, string[]> group -> where it is defined: setup() and spec file names
M.where = {}

---@param msg string
local function warn(msg)
  events.report(msg, vim.log.levels.WARN)
end

--- Define a group, or add to one. Keys that are not strings, a wrapping table's specs,
--- are skipped, and so is `group`, its name.
---@param name string
---@param fields table
---@param where? string the file it came from, for warnings; nil for one cinch-groups makes
function M.define(name, fields, where)
  local group = M.groups[name] or {}
  M.groups[name] = group
  M.where[name] = M.where[name] or {}
  local shown = where and (where == 'setup()' and where or vim.fs.basename(where))
  if shown and not vim.list_contains(M.where[name], shown) then
    table.insert(M.where[name], shown)
  end
  where = where or 'cinch-groups'
  local unknown = {}
  for k, v in pairs(fields) do
    if type(k) == 'string' and k ~= 'group' then
      if k == 'load' and not loads[v] then
        warn(('%s: group `%s` has unknown load `%s`; it is ignored'):format(where, name, tostring(v)))
      elseif k == 'order' and type(v) ~= 'number' then
        warn(('%s: group `%s` has order `%s`, not a number; it is ignored'):format(where, name, tostring(v)))
      elseif k == 'order' then
        M.order[name] = v
      elseif k == 'together' and type(v) ~= 'boolean' then
        warn(('%s: group `%s` has together `%s`, not true or false; it is ignored'):format(where, name, tostring(v)))
      elseif k == 'together' then
        M.together[name] = v or nil
      elseif k == 'load' or spec.triggers[k] then
        group[k] = v
      else
        unknown[#unknown + 1] = k
      end
    end
  end
  table.sort(unknown)
  for _, k in ipairs(unknown) do
    warn(('%s: group `%s` has unknown field `%s`; it is ignored'):format(where, name, k))
  end
end

--- The groups of setup(): each one's strategy, and who is in it by `plugins` or `dir`.
--- Sorted by name, so a plugin two groups list goes to the same one every start.
---@param groups table<string, cinch.Group>
---@param where string
function M.from_setup(groups, where)
  local names = vim.tbl_keys(groups)
  table.sort(names)
  for _, name in ipairs(names) do
    local fields = vim.deepcopy(groups[name])
    for _, plugin in ipairs(fields.plugins or {}) do
      if M.listed[plugin] and M.listed[plugin] ~= name then
        local msg = '%s: `%s` is listed in groups `%s` and `%s`; using `%s`'
        warn(msg:format(where, plugin, M.listed[plugin], name, M.listed[plugin]))
      else
        M.listed[plugin] = name
      end
    end
    local dir = fields.dir == true and name or fields.dir
    if type(dir) == 'string' then
      local clean = vim.trim(dir):gsub('^/+', ''):gsub('/+$', '')
      M.dirs[#M.dirs + 1] = { dir = '/' .. clean .. '/', group = name }
      M.dir_of[name] = clean .. '/'
    end
    fields.plugins, fields.dir = nil, nil
    M.define(name, fields, where)
  end
end

--- The group whose `dir` holds a spec file: the first that matches.
---@param file? string
---@return string?
function M.dir_group(file)
  if not file or #M.dirs == 0 then
    return
  end
  file = vim.fs.normalize(file)
  for _, d in ipairs(M.dirs) do
    if file:find(d.dir, 1, true) then
      return d.group
    end
  end
end

return M
