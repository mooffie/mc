--- @module ui

local M = {}

--- Dialog widget.
-- @section

--[[-

Runs the dialog.

This is like @{run} except that the dialog is shown near the cursor,
which is where users typically expect "popup" boxes to appear.

Popup dialogs often have a listbox, functioning as a menu. If you pass
the optional **lstbx** argument, this listbox will be resized to show all
its items but won't exceed the screen's size.

See examples at @{ui.Editbox.current_word} and
@{git:editbox/speller.lua|speller.lua}.

@method dialog:popup
@args ([lstbx])

]]

function M.popup(self, lstbx)

  if lstbx then

    lstbx:set_cols(math.min(lstbx:widest_item() + 2, tty.get_cols()))
    -- As long as the dialog is wider than the screen, shrink the listbox.
    while self:preferred_cols() > tty.get_cols()
        and lstbx:get_cols() > 5  -- show at least 5 columns
    do
      lstbx:set_cols(lstbx:get_cols() - 1)
    end

    lstbx:set_rows(0)
    lstbx:set_rows(
      math.max(
        math.min((tty.get_rows() - 2) - self:preferred_rows(), #lstbx.items),
        1
      )
    )

  end

  -- Get cursor position.
  local cx, cy = tty.get_canvas():get_xy()

  -- We start showing the dialog from the cursor down.
  local x, y = cx, cy + 1

  -- If no room "from the cursor down"...
  if y + self:preferred_rows() > tty.get_rows() then
    -- ...we show it "from the cursor up".
    y = cy - self:preferred_rows()
    -- If no room "from the cursor up"...
    if y <= 0 then
      -- ...we align it to the bottom of screen.
      y = tty.get_rows() - self:preferred_rows()
      -- ...and if there's no room for the dialog at all, at least we make its top visible:
      if y <= 0 then
        y = 0
      end
    end
  end

  --
  -- Now we manage the "x" axis.
  --

  -- If no room to the right...
  if x + self:preferred_cols() > tty.get_cols() then
    -- ...we align it to screen's right.
    x = tty.get_cols() - self:preferred_cols()
    -- ...and if still no room for the dialog, at least make its left visible:
    if x + self:preferred_cols() > tty.get_cols() then
      x = 0
    end
  end

  self:set_dimensions(x,y)

  return self:run()

end

return M
