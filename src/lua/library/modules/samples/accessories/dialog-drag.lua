--[[

Lets the user move dialogs by dragging their frame.

Installation:

    require('samples.accessories.dialog-drag').install()

Rationalization:

Sometimes dialogs obscure important data and we want them out of the way.
Examples are the editor's "replace" dialog, and copy/move progress
dialogs. This module lets you move such dialogs.

How it works:

This module works by inserting 4 "transparent" widgets at the 4 edges of
a dialog, covering its frame and responding to mouse events.

Misc:

If you want to move dialogs with the keyboard instead of the mouse,
see 'tests/snippets/dialog_mover.lua'.

]]

local M = {
  style = {
    normal = {
      frame = 'dialog.dtitle',
    },
    alarm = {
      frame = 'error.errdtitle',
    },
    pmenu = {
      frame = 'popupmenu.menutitle',
    }
  },
}

local function style(dlg, name)
  return tty.style((M.style[dlg.colorset] or M.style.normal)[name])
end

--
-- Move a dialog.
--
-- We can't just assign to dlg.x and dlg.y because the child widgets
-- have their .x and .y in absolute screen coordinates. So we have to
-- do the arithmetic on every child.
--
local function move_dlg(dlg, dx, dy)
  local function translate(wgt)
    wgt.x = wgt.x + dx
    wgt.y = wgt.y + dy
  end
  translate(dlg)
  for wgt in dlg:gmatch() do
    translate(wgt)
  end
  tty.redraw()
end

-- We don't want to drag fullscreen dialogs.
local function is_fullscreen(dlg)
  return dlg.x == 0 and dlg.y == 0 and dlg.cols == tty.get_cols() and dlg.rows == tty.get_rows()
end

------------------------------ The mover widget ------------------------------

-- The "mover" widget is a transparent handle injected at edges of a dialog.

local DBG = false  -- You may set this to 'true' to see the widget.

local Mover = ui.Custom.subclass("Mover")

Mover.__allowed_properties = {
  _dbg_id = true,
  previously_focused = true,
  drag_start = true,
}

function Mover:init()
  self._dbg_id = '?'
end

if DBG then
  function Mover:on_draw()
    local c = self:get_canvas()
    c:set_style(tty.style 'yellow, red')
    c:erase(self._dbg_id)
  end
end

function Mover:on_mouse_down(x, y, ...)
  self.dialog.data.is_dragging = true
  self.dialog:fixate()

  self.previously_focused = self.dialog.current
  -- The following is not mandatory, but by focusing the widget
  -- we prevent mouse events from landing in other widgets (e.g. listboxes)
  -- when the mouse is moved fast.
  self:focus()

  self.drag_start = { x = x, y = y }
  tty.redraw()  -- Update the dialog's frame.
end

function Mover:on_mouse_up(x, y, ...)
  if self.previously_focused then
    self.previously_focused:focus()
  end

  self.dialog.data.is_dragging = false
  tty.redraw()  -- Update the dialog's frame.
end

function Mover:on_mouse_drag(x, y, ...)
  local dx = x - self.drag_start.x
  local dy = y - self.drag_start.y
  move_dlg(self.dialog, dx, dy)
end

function Mover:on_focus()
  if self.dialog.data.is_dragging then
    -- Allow the 'self:focus()' above to work.
    return true
  else
    -- Don't let the user tab to this widget.
    return false
  end
end

------------------------------------------------------------------------------

function M.install()

  ui.Dialog.bind('<<open>>', function(dlg)

    if is_fullscreen(dlg) then
      return
    end

    -- Remember the focused widget.
    local focused = dlg.current

    local SZ = dlg.compact and 1 or 2  -- the size (width) of the frame.

    local bor = utils.bit32.bor

    -- Top edge
    dlg:map_widget(ui.Mover {
      _dbg_id = 1;
      x = 0,
      y = 0,
      cols = dlg.cols,
      rows = SZ,
      pos_flags = bor(ui.WPOS_KEEP_HORZ, ui.WPOS_KEEP_TOP),
    }:fixate())

    -- Bottom edge
    dlg:map_widget(ui.Mover {
      _dbg_id = 2;
      x = 0,
      y = dlg.rows - SZ,
      rows = SZ,
      cols = dlg.cols,
      pos_flags = bor(ui.WPOS_KEEP_HORZ, ui.WPOS_KEEP_BOTTOM),
    }:fixate())

    -- Left edge
    dlg:map_widget(ui.Mover {
      _dbg_id = 3;
      x = 0,
      y = SZ,
      cols = SZ,
      rows = dlg.rows - 2 * SZ,
      pos_flags = bor(ui.WPOS_KEEP_VERT, ui.WPOS_KEEP_LEFT),
    }:fixate())

    -- Right edge
    dlg:map_widget(ui.Mover {
      _dbg_id = 4;
      x = dlg.cols - SZ,
      y = SZ,
      cols = SZ,
      rows = dlg.rows - 2 * SZ,
      pos_flags = bor(ui.WPOS_KEEP_VERT, ui.WPOS_KEEP_RIGHT),
    }:fixate())

    -- Restore the previously focused widget, as map_widget() changed it.
    --
    -- The help dialog itself is a nasty beast: its interior widget
    -- covers the frame (for no good reason). If this interior is
    -- focused it will grab our mouse clicks, so we prevent this.
    if focused and dlg.text ~= T"Help" then
      focused:focus()
    end

  end)

  -- When a dialog is being dragged, draw a frame to indicate this.
  ui.Dialog.bind('<<draw>>', function(dlg)
    if dlg.data.is_dragging then
      local c = dlg:get_canvas()
      local MARGIN = dlg.compact and 0 or 1

      c:set_style(style(dlg, 'frame'))
      c:draw_box(MARGIN, MARGIN, dlg.cols - MARGIN*2, dlg.rows - MARGIN*2)
    end
  end)

end

return M
