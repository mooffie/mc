-- Demonstrates a roundabout way to close a dialog.

keymap.bind('C-v', function()
  local w = ui.current_widget()
  if w then
    w.dialog:command "cancel"
  end
  -- Or we can just do ui.Dialog.top:command("cancel") !

  -- We use :command("cancel") instead of :close() because the later merely
  -- stops the event loop: it doesn't concern itself with whether the user
  -- wants to approve or to cancel the action. :command("cancel"), OTOH, also
  -- marks the dialog as having been canceled (cf. 'h->ret_value = B_CANCEL'
  -- in C) so the code opening it knows to not carry out the action. Using
  -- :close() would lead some dialogs (Copy/Move) to think the user has OK'ed
  -- the action.
end)
