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
--    keymap.bind('C-y', function()
--      devel.view(_G)
--    end)
--
-- Note-short: If the UI is not ready, the output will be written to stdout.
--
-- @args (v)
function devel.view(v)
  alert(devel.pp(v))
end

return devel
