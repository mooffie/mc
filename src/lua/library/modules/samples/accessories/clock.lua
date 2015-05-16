--[[

Displays a clock at the top-right corner.

Installation:

    require('samples.accessories.clock').install()

or:

    local clock = require('samples.accessories.clock')
    clock.format = ...
    clock.style = ....
    clock.install()

]]


local M = {
  format = " %H:%M:%S ",
  style = { color="white, red", mono="reverse" },
  interval = 1000,
}

local style = nil

local function tick()
  local c = tty.get_canvas()

  -- Compile the style.
  if not style then
    style = tty.style(M.style)
  end

  local saved_x, saved_y = c:get_xy()

  local clock = os.date(M.format)
  c:goto_xy(tty.get_cols() - clock:len() - 2, 0)
  c:set_style(style)
  c:draw_string(clock)

  --
  -- Restore the cursor position.
  --
  -- Alternatively, instead of using these two variables (saved_x/y), we
  -- can simply do 'ui.Dialog.top:redraw_cursor()'.
  --
  c:goto_xy(saved_x, saved_y)

  tty.refresh()
end

event.bind('ui::skin-change', function()
  style = nil
end)

function M.install()
  timer.set_interval(tick, M.interval)
end

return M
