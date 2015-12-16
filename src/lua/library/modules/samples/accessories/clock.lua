--[[

Displays a clock at the top-right corner.

Installation:

    require('samples.accessories.clock').install()

Or, with customization:

    local clock = require('samples.accessories.clock')
    clock.format = ' %a %I:%M:%S %p '  -- Do "man strftime" for the available tokens (for Lua 5.2+, see LUA_STRFTIMEOPTIONS in loslib.c).
    clock.style.color = 'white, green'
    clock.install()

Instead of 'format' you can provide a function to generate the text:

    local clock = require('samples.accessories.clock')
    clock.get_text = function()
      return os.date('%H:%M:%S') .. ' | ' .. math.floor(collectgarbage 'count')
    end
    clock.style.color = 'white, green'
    clock.install()
    -- See dev_clock.lua if you're interested in such debug info.

If you're conscious about CPU usage, you can make the clock tick less
frequently:

    ...
    clock.interval = 5000  -- Tick every five seconds instead of 1 second.
    clock.install()

]]


local M = {
  format = " %H:%M:%S ",
  style = { color="black, brown", mono="reverse" },
  interval = 1000,
}

local style = nil

function M.get_text()
  return os.date(M.format)
end

local function tick()
  local c = tty.get_canvas()

  -- Compile the style.
  if not style then
    style = tty.style(M.style)
  end

  local saved_x, saved_y = c:get_xy()

  local clock = M.get_text()
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

function M.install()
  timer.set_interval(tick, M.interval)
  M.install = function() end  -- Don't let people install() us more than once.
end

return M
