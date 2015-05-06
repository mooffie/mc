
-- Checks GC in Lua 5.2+.
--
-- This demonstration code was taken from a comment in luaUI_push_registered_widget(). See explanation there.

local function test()

  for i = 1, 100 do
    do
      -- Note: the label has to come first, because Lua GC in reverse order and we
      -- want the dialog to GC first.
      local lbl1 = ui.Label("hello")
      local lbl2 = ui.Label("hello")
      local lbl3 = ui.Label("hello")
      local lbl4 = ui.Label("hello")
      local dlg = ui.Dialog()

      dlg:add(lbl1, lbl2, lbl3, lbl4)
      dlg:map_all() -- what actually adds the widgets to the dialog.
    end
    collectgarbage()
    collectgarbage()
    collectgarbage()
    collectgarbage()
  end

end

--[[

The debug output should say:

__gc of alive Dialog
__gc of destroyed Label
__gc of destroyed Label
__gc of destroyed Label
__gc of destroyed Label

@todo: investigate why, when run in MC, debugging output says "__gc of C-created alive Panel"
in every iteration, and why does the hint line gets updated.

]]

test()
--keymap.bind('C-y', test)
