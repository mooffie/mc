--[[

  A screensaver showing an analog clock.

  To install:

    require('samples.screensavers.clocks.analog').install()

  (or do '.install(5*60*1000)' to kick in after 5 minutes, for example,
  instead of the default 1 minute.)

  You may invoke it outright by doing, e.g.:

    keymap.bind('C-d', function()
      require('samples.screensavers.clocks.analog').run()
    end)

]]

--[[

PROGRAMMERS:

First see screensavers/simplest.lua to learn how a screensaver is arranged.

]]

local wrapper_dialog, create_installer = import_from('samples.screensavers.utils', { 'wrapper_dialog', 'create_installer' })
local floor = math.floor

local M = {}

M.style = {
  background = "yellow, black",
  hand_second = "red, black; reverse",
  hand_hours = "yellow, black; reverse",
  hand_minutes = "yellow, black; reverse",
  numerals = "white, black",
}

--
-- The following was taken from
--   http://en.wikipedia.org/wiki/Bresenham's_line_algorithm
--
local function draw_line__lowlevel(c, x0, y0, x1, y1, plot)

  local steep = math.abs(y1 - y0) > math.abs(x1 - x0)
  if steep then
    x0, y0 = y0, x0
    x1, y1 = y1, x1
  end
  if x0 > x1 then
    x0, x1 = x1, x0
    y0, y1 = y1, y0
  end

  local deltax = x1 - x0
  local deltay = math.abs(y1 - y0)
  local error = floor(deltax / 2)  -- we don't *have* to coerce it to int, but the algorithm prides itself on being floats-free.
  local ystep
  local y = y0
  if y0 < y1 then ystep = 1 else ystep = -1 end
  for x = x0, x1 do
    if steep then plot(y,x) else plot(x,y) end
    error = error - deltay
    if error < 0 then
      y = y + ystep
      error = error + deltax
    end
  end
end

local function draw_line(c, x0, y0, x1, y1)
  local function plot(x,y)
    c:goto_xy(x,y)
    c:draw_string(' ')
  end

  -- The algorithm would work even if these were floats, but goto_xy() accepts
  -- only integers and it's more efficient to do the conversion once, here.
  x0, y0, x1, y1 = floor(x0), floor(y0), floor(x1), floor(y1)

  draw_line__lowlevel(c, x0, y0, x1, y1, plot)
end

local function calculate_hand_coordinates(c, angle, length)

  local aspect_ratio = 2 -- We can only assume this is so.
  local center_x, center_y = c:get_cols() / 2, c:get_rows() / 2
  local full = c:get_rows() / 2 - 2

  angle = 90 - angle

  local x = center_x + math.cos(math.rad(angle)) * (full * length * aspect_ratio)
  local y = center_y - math.sin(math.rad(angle)) * (full * length)

  return x, y, center_x, center_y

end

-- Angle is in degrees. Zero is at 12 o'clock.
local function draw_hand(c, angle, length)
  draw_line(c, calculate_hand_coordinates(c, angle, length))
end


local style = nil

local function draw(c)

  -- Compile the styles.
  if not style then
    style = utils.table.map(M.style, tty.style)
  end

  c:set_style(style.background)
  c:erase()

  local time = os.date("*t")

  -- seconds hand
  c:set_style(style.hand_second)
  local second_angle = (time.sec / 60) * 360
  draw_hand(c, second_angle, 1.0)

  -- hours hand
  c:set_style(style.hand_hours)
  local hour_angle = (time.hour % 12 + time.min / 60) / 12 * 360
  draw_hand(c, hour_angle, 0.65)

  -- minutes hand
  c:set_style(style.hand_minutes)
  local minute_angle = (time.min + time.sec / 60) / 60 * 360
  draw_hand(c, minute_angle, 1.0)

  -- the 12 numerals.
  c:set_style(style.numerals)
  for i = 1, 12 do
    local x, y = calculate_hand_coordinates(c, i/12*360, 1.0)
    c:goto_xy(floor(x), floor(y))
    c:draw_string(i)
  end

end

function M.run()
  local clockface = ui.Custom()
  local dlg = wrapper_dialog(clockface)

  clockface.on_draw = function()
    draw(clockface:get_canvas())
  end

  -- The responsibility to close the dialog on any keypress is ours.
  clockface.on_hotkey = function(self, kcode)
    dlg:close()
    return true
  end

  local intvl = timer.set_interval(function()
    clockface:redraw()
    dlg:refresh()
  end, 1000) -- "1000" means: refresh every second. That's the maximum resolution os.date() gives us.

  dlg:run()

  intvl:stop()
end

M.install = create_installer(M.run)

return M
