-- A roundabout way to close a dialog.
keymap.bind('C-v', function()
  local w = ui.current_widget()
  if w then
    w.dialog:close()
  end
  -- Or we could just do ui.Dialog.top:close()

  -- However, we should prefer :command("cancel") to :close(), for a
  -- reason explained in dialog-icons.lua.
end)
