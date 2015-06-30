--[[

Tests y-axis placement of dialogs.

Dialogs often aren't really centered on the y axis: they're moved up one
or two lines. On the C side this logic is triggered by the DLG_TRYUP
flag. But Lua dialogs don't use this flag: the calculation is done for
them in ui.Dialog:set_dimensions().

This script displays a horizontal line where ui.Dialog:set_dimensions()
would have placed the current dialog. Use it to verify that Lua and C do
the same calculation.

Also check out commit 5b243eb9e (ticket #3173): it introduces a change in
C's handling of DLG_TRYUP.

]]

local dummy = nil

ui.Dialog.bind('<<draw>>', function(dlg)

  if not dummy or not dummy:is_alive() then  -- is_alive = when restarting lua.
    dummy = ui.Dialog()
  end

  if dlg.y == 0 then
    return
  end

  dummy:set_dimensions(nil, nil, dlg.cols, dlg.rows)

  do
    local c = tty.get_canvas()
    c:goto_xy(0, dummy.y)
    c:set_style(tty.style('yellow, base'))
    c:draw_string(string.rep("#", dlg.x))
  end

end)
