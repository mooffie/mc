--[[

Easily un-filter and un-panelize a panel.

Installation:

    ui.Panel.bind('C-r', require('samples.accessories.unfilter').run)

Rationalization:

MC seems to have no hotkey to do this. We suggest that you attach this
action to C-r (the key used for reloading), as the example above shows.

Note that un-filtering and un-panelizing does *not* clear your marked
files. They remain marked. This is an important usability feature: Sometimes
your purpose in filtering (or panelizing) is to aid you in marking files,
and you certainly don't want these markings lost when you go back to
the full view.

]]

local M = {}

function M.run(pnl)
  if pnl.panelized then  -- The check is not critical, but assigning causes redraw, which we can save.
    pnl.panelized = false
  end
  if pnl.filter then  -- Assigning causes reload, and we don't want to do it needlessly.
    pnl.filter = nil
  end
  return false  -- Continue to the default action (e.g., reloading).
end

-- We can instead return the function itself. But we don't want to confuse
-- users (or programmers) so we stick to the established practice of returning
-- a module.

return M
