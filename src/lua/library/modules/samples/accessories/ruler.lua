--[[

Displays a ruler you can move on screen to measure columns and rows.

Installation:

    keymap.bind('M-r', function()
      require('samples.accessories.ruler').run()
    end)

Tips / notes:

- The initial position of the ruler is at the cursor position. This works
  swell for the editor, though in other places (e.g. the viewer) this
  position is somewhat "weird".

- You can display several rulers simultaneously.

- You can move the axes' origin off screen.

- Moving the ruler, especially with the mouse, might seem sluggish sometimes.
  It's not because Lua is slow (it isn't) but because the windows underneath
  are asked to draw themselves.

]]

local M = {
  style = {
    instructions = 'error._default_',
    ones = 'core.selected',
    tens = 'core.markselect',
  },
  half = false,
  show_instructions = true,
}


function M.run()

  local dlg = ui.Dialog()

  local ruler = ui.Custom()

  local style = utils.table.map(M.style, tty.style)

  ---------------------------------- Setup -----------------------------------

  -- There are various ways to implement the ruler. We use the following:
  --
  -- We place a dialog over the whole screen. In it we place the ruler.
  -- Everything is conventional except that we tweak the dialog's on_draw
  -- to make it seem like transparent.

  dlg.on_resize = function(self)
    -- Note the '-1': if the dialog covered absolutely the whole screen,
    -- tty.redraw() would not bother drawing the dialogs beneath (see
    -- WDialog.fullscreen on the C side).
    self:set_dimensions(0, 0, tty.get_cols(), tty.get_rows() - 1)
    ruler.cols = self.cols
    ruler.rows = self.rows
  end
  dlg:on_resize()
  dlg:map_widget(ruler)

  do
    -- We redefine the dialog's 'on_draw' to draw the dialogs beneath
    -- (instead of its own background), by calling tty.redraw(). Since
    -- tty.redraw() is going to call us, we implement a lock to prevent
    -- infinite loop.

    local lock = false

    dlg.on_draw = function()

      if lock then
        return true
      end

      lock = true
      tty.redraw()
      lock = false

      if M.show_instructions then
        local c = tty.get_canvas()
        c:set_style(style.instructions)
        c:goto_xy(0,0)
        c:draw_string(T"Ruler is active. Use arrows/mouse. ESC/Enter quits. 'h' toggles half axis. 'i' toggles msg.")
      end

      return true

    end

  end

  -------------------------------- App cursor --------------------------------

  -- We don't have to, but we constantly show the cursor at its
  -- original spot.

  local orig_x, orig_y = tty:get_canvas():get_xy()

  ruler.on_cursor = function()
    tty.get_canvas():goto_xy(orig_x, orig_y)
  end
  -- To make our widget focusable, we must also do:
  ruler.on_focus = function() return true end

  dlg.on_init = function()
    ruler:focus()
  end

  --------------------------------- Drawing ----------------------------------

  local ox, oy = orig_x - 1, orig_y + 1  -- (ox, oy) = the axes origin.

  ruler.on_draw = function()

    local c = tty:get_canvas()

    local function draw_digit(i)
      if i % 10 == 0 then
        c:set_style(style.tens)
        c:draw_string(((i%100)..""):sub(1,1))
      else
        c:set_style(style.ones)
        c:draw_string((i..""):sub(-1))
      end
    end

    --
    -- The 'y' axis.
    --

    local i = 0
    for x = ox, tty.get_cols() - 1 do
      c:goto_xy(x, oy)
      draw_digit(i)
      i = i + 1
    end

    if not M.half then
      local i = 0
      for x = ox, 0, -1 do
        c:goto_xy(x, oy)
        draw_digit(i)
        i = i + 1
      end
    end

    --
    -- The 'x' axis.
    --

    local i = 0
    for y = oy, tty.get_rows() - 1 do
      c:goto_xy(ox, y)
      draw_digit(i)
      i = i + 1
    end

    if not M.half then
      local i = 0
      for y = oy, 0, -1 do
        c:goto_xy(ox, y)
        draw_digit(i)
        i = i + 1
      end
    end

  end

  ------------------------------ Mouse support -------------------------------

  ruler.on_mouse_down = function (self, x, y) 
    ox, oy = x, y
    dlg:redraw()
  end
  ruler.on_mouse_drag = ruler.on_mouse_down

  ------------------------------- Key bindings -------------------------------

  local K = utils.magic.memoize(tty.keyname_to_keycode)

  dlg.on_key = function(self, kcode)
    if kcode == K'right' then
      ox = ox + 1
    elseif kcode == K'left' then
      ox = ox - 1
    elseif kcode == K'up' then
      oy = oy - 1
    elseif kcode == K'down' then
      oy = oy + 1
    elseif kcode == K'h' then
      M.half = not M.half
    elseif kcode == K'i' then
      M.show_instructions = not M.show_instructions
    else
      return false
    end
    dlg:redraw()
    return true
  end

  ----------------------------------------------------------------------------

  dlg:run()

end

------------------------------------------------------------------------------

return M
