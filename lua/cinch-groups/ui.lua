-- Groups in cinch's window: a chip with each plugin's group on its row, `group` and
-- `took` lines in its pane, `/group:<name>` in the filter, a Groups tab before Triggers,
-- and <C-g> in Plugins to list by group instead of by state. Drawing code is required
-- only when the window draws.

local M = {}

local GROUP_ICON = '\u{f247}'

---@return table
local function groups()
  return require('cinch-groups')
end

---@return table
local function registry()
  return require('cinch-groups.registry')
end

---@return table
local function assign()
  return require('cinch-groups.assign')
end

---@return string
local function icon()
  local ui = package.loaded['cinch.features.ui']
  local own = ui and ui.opts.icons
  return own and own.group or GROUP_ICON
end

--- A group's strategy as chips, the way rows show how a plugin loads: a chip per
--- trigger with its values after it, or `load` when it has no trigger.
---@param fields table<string, any>
---@return { [1]: string, [2]?: string }[]
local function strategy(fields)
  local rows = require('cinch.features.ui.rows')
  local kinds = {}
  for k in pairs(fields) do
    if k ~= 'load' then
      kinds[#kinds + 1] = k
    end
  end
  table.sort(kinds)
  local items = {}
  for _, k in ipairs(kinds) do
    local item = rows.kind_chip(k)
    local v = fields[k]
    for _, x in ipairs(type(v) == 'table' and v or { v }) do
      item[#item + 1] = { ' ' }
      item[#item + 1] = { type(x) == 'table' and (x.lhs or x[1] or '') or tostring(x), 'CinchTriggerValue' }
    end
    items[#items + 1] = item
  end
  if fields.load and #kinds == 0 then
    items[#items + 1] = rows.kind_chip(fields.load == 'now_if_args' and 'later' or fields.load)
  elseif fields.load then
    items[#items + 1] = { { 'load ' .. fields.load, 'CinchMuted' } }
  end
  return rows.join(items)
end

--- What a plugin took from its group, in the pane: triggers, then `load <how>`.
---@param took table<string, any>
---@return { [1]: string, [2]?: string }[]
local function took_chunks(took)
  local out = {}
  local kinds = vim.tbl_keys(took)
  -- Triggers by name, then `load`.
  table.sort(kinds, function(a, b)
    if (a == 'load') ~= (b == 'load') then
      return b == 'load'
    end
    return a < b
  end)
  local rows = require('cinch.features.ui.rows')
  for i, k in ipairs(kinds) do
    if i > 1 then
      out[#out + 1] = { ' · ', 'CinchMuted' }
    end
    if k == 'load' then
      out[#out + 1] = { 'load ' .. took[k] }
    else
      vim.list_extend(out, rows.kind_chip(k))
      local v = took[k]
      for _, x in ipairs(type(v) == 'table' and v or { v }) do
        out[#out + 1] = { ' ' .. (type(x) == 'table' and (x.lhs or x[1] or '') or tostring(x)), 'CinchTriggerValue' }
      end
    end
  end
  return out
end

--- How a plugin joined its group, after the group's name in the pane.
---@param how { how: string, file?: string }
---@return string
local function joined(how)
  if how.how == 'file' then
    return 'file ' .. how.file
  elseif how.how == 'wrap' then
    return 'wraps its spec'
  elseif how.how == 'listed' then
    return 'listed in setup()'
  elseif how.how == 'dir' then
    return 'dir ' .. how.file
  elseif how.how == 'dep' then
    return 'dependency'
  end
  return 'its spec names it'
end

--- Every group by `order`, then name.
---@return string[]
local function ordered(names)
  local reg = registry()
  table.sort(names, function(a, b)
    local x, y = reg.order[a] or reg.default_order, reg.order[b] or reg.default_order
    if x ~= y then
      return x < y
    end
    return a < b
  end)
  return names
end

--- Loaded and total plugins of a list.
---@param list cinch.Plugin[]
---@return integer loaded, integer total
local function count(list)
  local n = 0
  for _, p in ipairs(list) do
    n = n + (p.state == 'loaded' and 1 or 0)
  end
  return n, #list
end

--- A plugin's group. Every plugin has one; one cinch-groups never saw, registered before
--- it started say, is in the group of the file its spec is in.
---@param p cinch.Plugin
---@return string
local function group_of(p)
  local g = groups().of(p.name)
  if g then
    return g
  end
  local file = p.origin and p.origin.file
  return file and vim.fn.fnamemodify(file, ':t:r') or assign().DEPS
end

--- The plugins of each group, in declaration order. cinch and its extensions are not yours.
---@return table<string, cinch.Plugin[]>
local function by_group()
  local out = {}
  for _, p in ipairs(require('cinch.state').yours()) do
    local g = group_of(p)
    out[g] = out[g] or {}
    table.insert(out[g], p)
  end
  for name in pairs(registry().groups) do
    out[name] = out[name] or {}
  end
  return out
end

-- The Groups view --------------------------------------------------------------

local ID = 'group:' -- a group row's id, before its name

---@param c cinch.ui.Canvas
---@param name string
---@param list cinch.Plugin[]
---@param slowest number
local function group_row(c, name, list, slowest)
  local canvas, rows = require('cinch.features.ui.canvas'), require('cinch.features.ui.rows')
  local loaded, total = count(list)
  local light = loaded == total and total > 0 and '●' or loaded > 0 and '◐' or '○'
  local light_hl = loaded == total and total > 0 and 'CinchLoaded' or 'CinchWaiting'
  local ms = 0
  for _, p in ipairs(list) do
    ms = ms + (rows.load_ms(p) or 0)
  end
  local reg = registry()
  local items = {
    { { ' ' .. light, light_hl } },
    { { name, 'CinchName' } },
    { { tostring(reg.order[name] or reg.default_order), 'CinchMuted' } },
  }
  if ms > 0 then
    items[#items + 1] = { { '(' .. canvas.ms(ms) .. ')', 'CinchMuted' } }
    items[#items + 1] = canvas.pill(ms, slowest, 6)
  end
  items[#items + 1] = strategy(reg.groups[name] or {})
  items[#items + 1] = { { ('%d/%d'):format(loaded, total), 'CinchMuted' } }
  c:add(canvas.clip(rows.join(items), c.width - 1), { plugin = ID .. name, section = ID .. name })
end

---@param width integer
---@param ctx cinch.ui.Ctx
---@return cinch.ui.Canvas
local function list(width, ctx)
  local canvas, rows = require('cinch.features.ui.canvas'), require('cinch.features.ui.rows')
  local c = canvas.new(width)
  local all = by_group()
  -- The bar's full length: the slowest group, all its load times together.
  local slowest = 0
  for _, ps in pairs(all) do
    local ms = 0
    for _, p in ipairs(ps) do
      ms = ms + (rows.load_ms(p) or 0)
    end
    slowest = math.max(slowest, ms)
  end
  local needed = rows.dependents()
  for _, name in ipairs(ordered(vim.tbl_keys(all))) do
    local ps = all[name]
    if #ps > 0 then
      -- Shut until opened: the fold key marks a group open.
      local open = ctx.folded[ID .. name] == true
      group_row(c, name, ps, slowest)
      for _, p in ipairs(open and ps or {}) do
        local m, m_hl = rows.mark(p, ctx.tick)
        rows.add_row(c, p, {
          mark = m,
          mark_hl = m_hl,
          ms = rows.load_ms(p),
          slowest = slowest,
          needed_by = needed[p.name] or {},
          indent = true,
        })
      end
    end
  end
  return c
end

---@param id string?
---@param width integer
---@param ctx cinch.ui.Ctx
---@return cinch.ui.Canvas
local function pane(id, width, ctx)
  local canvas, rows = require('cinch.features.ui.canvas'), require('cinch.features.ui.rows')
  if not (id and vim.startswith(id, ID)) then
    return require('cinch.features.ui.details').pane(id, width, ctx)
  end
  local name = id:sub(#ID + 1)
  local c = canvas.new(width)
  local key_w = 10
  local function kv(key, chunks)
    c:add(canvas.clip(vim.list_extend({ { ' ' .. canvas.fit(key, key_w), 'CinchMuted' } }, chunks), c.width - 1))
  end
  local ps = by_group()[name] or {}
  local reg = registry()
  c:add({ { ' ' .. name, 'CinchTitle' } })
  c:add({ { ' ' .. ('─'):rep(c.width - 2), 'CinchRule' } })
  kv('order', { { tostring(reg.order[name] or reg.default_order) } })
  kv('load', strategy(reg.groups[name] or {}))
  if reg.together[name] then
    kv('together', { { 'yes' } })
  end
  if #(reg.where[name] or {}) > 0 then
    kv('defined', { { table.concat(reg.where[name], ', ') } })
  end
  for i, p in ipairs(ps) do
    local m, m_hl = rows.mark(p, ctx.tick)
    local how = assign().how[p.name]
    kv(i == 1 and 'plugins' or '', {
      { m .. ' ', m_hl },
      { canvas.fit(p.name, 18), 'CinchName' },
      { how and (' ' .. joined(how)) or '', 'CinchMuted' },
    })
  end
  return c
end

--- l on a group loads it; on one of its plugins, that plugin.
---@param id string?
local function load(id)
  if id and vim.startswith(id, ID) then
    groups().load(id:sub(#ID + 1))
  elseif id then
    require('cinch').load({ id })
  end
end

--- u on a group: its plugins with updates, asked on their rows in Plugins.
---@param id string?
---@param ctx cinch.ui.Ctx
local function update(id, ctx)
  local u = package.loaded['cinch.features.updates']
  if not (u and id and vim.startswith(id, ID)) then
    return
  end
  local name = id:sub(#ID + 1)
  local names = vim.tbl_filter(function(n)
    return u.results[n] ~= nil
  end, groups().members(name))
  if #names == 0 then
    return u.apply({})
  end
  local ui = require('cinch.features.ui')
  ctx.filter = 'group:' .. name
  ui.open('plugins')
  if not require('cinch').confirms() then
    return u.apply(names)
  end
  ui.ask({
    verb = 'Update',
    names = names,
    done = function(yes)
      if yes then
        u.apply(names)
      end
    end,
  })
end

-- Plugins: by group --------------------------------------------------------------

---@type cinch.ui.Grouping
local grouping = {
  of = group_of,
  order = ordered,
  title = function(name, ps)
    local loaded, total = count(ps)
    local out = { { name, 'CinchSection' }, { (' %d/%d'):format(loaded, total), 'CinchMuted' }, { '  ' } }
    return vim.list_extend(out, strategy(registry().groups[name] or {}))
  end,
}

--- Add groups to cinch's window. Called from start(), with the ui feature loaded.
---@param ui table cinch.features.ui
function M.setup(ui)
  ui.add_chip(function(p)
    local g = groups().of(p.name)
    if g then
      local _, hl = require('cinch.features.ui.canvas').kind_hl('trigger')
      return { { icon() .. ' ' .. g, hl } }
    end
  end)
  ui.add_pane_lines(function(p, kv)
    local g = groups().of(p.name)
    if not g then
      return
    end
    local how = assign().how[p.name]
    kv('group', { { g }, { how and (' · ' .. joined(how)) or '', 'CinchMuted' } })
    local took = assign().took[p.name]
    if took and next(took) then
      kv('took', took_chunks(took))
    end
  end)
  ui.add_filter('group', function(p, value)
    return groups().of(p.name) == value
  end)

  ui.add_view('groups', { list = list, pane = pane }, { before = 'triggers' })
  ui.add_key({ lhs = { 'l' }, view = 'groups', desc = 'load', run = load })
  ui.add_key({ lhs = { 'u' }, view = 'groups', desc = 'update', run = update })

  ui.add_grouping('groups', grouping)
  ui.add_key({
    lhs = { '<C-g>' },
    view = 'plugins',
    desc = 'in Plugins, list by group or by state',
    run = function(_, ctx)
      ctx.grouping = not ctx.grouping and 'groups' or nil
    end,
  })
end

return M
