--[[

Notifies GNOME Terminal of the current directory. (For GT >= 3.7.0)

Installation:

    require('samples.accessories.set-gterm-cwd')

The idea was taken from:

    https://www.midnight-commander.org/ticket/3088
    "Tell the current directory to gnome-terminal"

]]

local function set_gterm_cwd(pnl)
  if pnl == ui.Panel.current then  -- <<load>> is fired for the "other" panel as well.
    if pnl.vdir:is_local() then    -- Local filesystem only: exclude archives etc. (Alternatively we can do 'fs.nonvfs_realpath(pnl.dir)')
      io.stdout:write("\27]7;file://" .. os.hostname() .. utils.text.transport.uri_encode(pnl.dir, "/") .. "\7")
      io.stdout:flush()
    end
  end
end

-- Ensure we don't trash the screen on incompatible terminals.
-- (See discussion at the URL above.)
if tonumber(os.getenv("VTE_VERSION") or 0) >= 3405 then
  ui.Panel.bind("<<load>>", set_gterm_cwd)      -- When the user navigates between directories.
  ui.Panel.bind("<<activate>>", set_gterm_cwd)  -- When the user switches between panels.
else
  devel.log(E"set-gterm-cwd.lua: Either you're not using GNOME Terminal, or yours is too old.")
end
