-- A "roundabout" way to close a dialog.
keymap.bind('C-v', function()
  local w = ui.current_widget()
  if w then
    w.dialog:close()
  end
  -- Or we could just do ui.Dialog.top:close()
end)
