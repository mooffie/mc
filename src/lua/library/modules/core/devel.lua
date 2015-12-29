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
-- "Pretty prints" a value into the viewer.
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
function devel.view(v, pp)
  if tty.is_ui_ready() then
    -- @todo: Once we have mc.view_string() we won't need to use a temporary file.
    local f, tempname = fs.temporary_file{prefix="devel"}
    f:write((pp or devel.pp)(v))
    f:close()
    mc.view(tempname)
    fs.unlink(tempname)
  else
    print(devel.pp(v))
  end
end

return devel
