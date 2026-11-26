-- cinch loads this for `extensions = { groups = { ... } }`, before it reads a spec.
local groups = require('cinch-groups')

return require('cinch').register_extension({
  setup = groups.start,
  exports = groups,
  health = groups.health,
})
