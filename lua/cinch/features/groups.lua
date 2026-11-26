-- The older way in, `features = { ..., 'groups' }` with `groups = { ... }`; kept so
-- configs written for it keep working. `extensions = { groups = { ... } }` is the new one.
return { setup = require('cinch-groups').start }
