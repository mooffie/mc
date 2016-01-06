--[[

Smooth scrolling in the viewer.

(It seems not to work too well in GNOME-Terminal. GT is quite sluggish
(see related comment in core/mcscript.lua). Or maybe its just my slow
computer. Try it out in xterm or the linux console to see it in its full
glory.)

]]

local lines_to_scroll_prc = 0.33  -- 33% of the viewer height.
local scroll_delay = 20  -- I wonder what effect the computer speed has on this. I'm using a slow computer (Pentium 4) with slow on-board video card.

local function do_smooth(v, cmd_name)

  local itvl
  local i = 1
  local lines_to_scroll = v.rows * lines_to_scroll_prc

  itvl = timer.set_interval(function()
    if v:is_alive() then  -- in case the user closes the viewer.
      v:command(cmd_name)
      tty.refresh()
    end
    if i >= lines_to_scroll then
      itvl:stop()
    end
    i = i + 1
  end, scroll_delay)

end

ui.Viewer.bind('pgdn', function(v)
  do_smooth(v, 'down')
end)

ui.Viewer.bind('pgup', function(v)
  do_smooth(v, 'up')
end)

-- Note: if you press and hold down the keys, multiple simultaneous intervals
-- will be created and you'll scroll faster.
