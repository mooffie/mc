--[[

Follows a symlink, or a panelized item, to its target.

Installation:

    local follow = require('samples.accessories.follow').follow

    ui.Panel.bind('C-x f', follow)

    ui.Panel.bind('C-x C-f', function(pnl)
      follow(ui.Panel.other or pnl)
    end)

    -- And, if you want to bind 'enter' on panelized listings:
    ui.Panel.bind('enter', function(pnl)
      -- If we're not panelized, or there's something typed at the commandline, then skip.
      if (not pnl.panelized) or (ui.current_widget("Input") and ui.current_widget("Input").text ~= "") then
        return false
      end
      follow(pnl)
    end)

Idea taken from:

    http://www.midnight-commander.org/ticket/2693
    "implement 'follow symlink' command"

    http://www.midnight-commander.org/ticket/2423
    "MC doesn't jump to a destination directory upon pressing Enter on found files in the 'Find Files' results panel"

]]

local M = {}

--
-- If the user stands on a symlink or panelized item, returns its target in
-- the form (dir, base). Else, returns nothing.
--
function M.get_target(pnl)

  local function join(dir, base)
    return dir .. (dir:find "/$" and "" or "/") .. base
  end

  local fname, stat, _, _, is_broken_symlink = pnl:get_current()

  if pnl.panelized then
    -- Nothing to do: we've already got the fname.
  elseif stat.type == 'link' and not is_broken_symlink then
    fname = fs.readlink(fname)
  else
    -- Neither panelized nor symlink: abort.
    return
  end

  if not fname:find '^/' then
    -- It's a relative path. Prepend the panel's dir.
    fname = join(pnl.dir, fname)
  end

  local dir, base = fname:match "(.*)/(.*)"
  if dir == "" then
    dir = "/"
  end

  return dir, base

end

--
-- Follow!
--
-- You must supply a destination panel.
--
function M.follow(pnl_dest)

  local dir, base = M.get_target(ui.Panel.current)

  if not dir then
    -- Nothing to follow!
    return
  end

  -- If the panel already shows the target dir, the target basename may
  -- already be on the screen. So we don't re-load this dir as this will
  -- scroll the list and the user will lose orientation.
  if pnl_dest.dir ~= dir or pnl_dest.panelized then
    pnl_dest.dir = dir
  end
  pnl_dest.current = base
  pnl_dest:focus()  -- When targeting the "other" panel, user probably wants to also go there.

end

return M
