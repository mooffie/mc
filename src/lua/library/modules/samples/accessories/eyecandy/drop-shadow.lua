--[[

Adds a drop-shadow effect to dialogs.

Installation:

    require('samples.accessories.eyecandy.drop-shadow').install()

or:

    local shadow = require('samples.accessories.eyecandy.drop-shadow')
    shadow.width = 4
    shadow.height = 2
    shadow.style = 'green, black'
    shadow.install()

]]

local M = {
  style = "gray, black",

  --- Characters on a terminal are usually tall, not square, so we make the width bigger.
  width = 2,
  height = 1,
}

local function drop_shadow(dlg)

  -- Don't waste time on full or half-screen dialogs.
  if dlg.x == 0 then
    return
  end

  local c = tty.get_canvas()
  -- Alternatively, we could have gotten a canvas by calling dlg:get_canvas().
  -- This might have simplified some arithmetic here.

  local shadow = M  -- looks better.

  c:set_style(tty.style(shadow.style))

  local dlg_right_col = dlg.x + dlg.cols - 1
  local dlg_bottom_row = dlg.y + dlg.rows - 1

  for y = dlg.y + shadow.height, math.min(dlg_bottom_row + shadow.height, tty.get_rows() - 1) do
    for x = dlg.x + shadow.width, math.min(dlg_right_col + shadow.width, tty.get_cols() - 1) do

      if x > dlg_right_col or y > dlg_bottom_row then
        c:goto_xy(x, y)
        local ch = c:get_char_at(x, y) or '?'
        c:draw_string(ch)
      end

    end
  end

end

function M.install()
  ui.Dialog.bind('<<draw>>', drop_shadow)
end

return M
