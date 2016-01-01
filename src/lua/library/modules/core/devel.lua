--- Development utilities.
-- @module devel

local devel = {}

require('utils.magic').setup_autoload(devel)
devel.autoload('ensure', 'devel.ensure')
devel.autoload('log', { 'devel.log', 'log' })

---
-- "Pretty prints" a value. It doesn't actually do any printing: it returns a string.
--
-- This function can handle complex structures: circular references in
-- tables are supported.
--
-- Example:
--
--    devel.log( devel.pp(fs) )
--
-- See also @{devel.view}, which you'll more often use.
--
-- @function pp
-- @args (v)

devel.autoload('pp', { 'devel.pp', 'pp' })

---
-- "Pretty prints" a value to the screen.
--
-- Example:
--
--    devel.view(_G)
--
-- @args (v)
function devel.view(v)
  print(devel.pp(v))
end

return devel
