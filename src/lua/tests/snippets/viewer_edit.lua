--[[

Runs the editor from the viewer.

Idea taken from:

    http://www.midnight-commander.org/ticket/2156
    "Run editor from viewer"

]]

ui.Viewer.bind("f4", function(vwr)
  local filename, top_line = vwr.filename, vwr.top_line
  abortive(filename, T"No file is associated with this viewer. Cannot edit.")
  vwr.dialog:close()
  --
  -- if we call mc.edit() outright, it will cancel the closing of
  -- the viewer.
  --
  -- That's because mc.edit() invokes a modaless dialog and such
  -- dialogs first set the state of the current modaless dialog (the
  -- viewer being closed) to "suspended" (overwriting the "closed" state).
  -- (See dialog-switch.c:dialog_switch_add().)
  --
  -- So we postpone mc.edit() to the next event loop iteration, when
  -- the viewer has already gone.
  --
  timer.set_timeout(function()
    timer.unlock()  -- See comment for similar line at the 'recently-visited-files' module.
    mc.edit(filename, top_line)
  end, 0)
end)

ui.Viewer.bind("s-f4", function(vwr)  -- invoke the original F4.
  vwr:command "HexMode"
end)
