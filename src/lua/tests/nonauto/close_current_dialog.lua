-- Demonstrates a roundabout way to close a dialog.

keymap.bind('C-v', function()
  local w = ui.current_widget()
  if w then
    w.dialog:command "cancel"
  end
  -- Or we can just do ui.Dialog.top:command("cancel") !

  -- We use :command("cancel"), not :close(). See explanation below.
end)

--[[

# There are two ways to close a dialog:

* dlg:close()
* dlg:command("cancel")

Both ways terminate the event loop. But :command("cancel") does something
further: it sets a flag on the dialog ('h->ret_value = B_CANCEL') that
tells the system that the user does not wish to carry out the action.

This is important! Using :close() instead would lead some dialogs
(Copy/Move) to think the user had OK'ed the action.

# So, why does :close() exist? What is it useful for?

It's useful in two cases:

(1) For use in Lua dialogs:

    my_button.on_click = function()
      dlg.result = "whatever"
      dlg:close()
    end

(2) Some built-in MC dialogs (e.g., the viewer) don't respond to
    CK_Cancel. So you can close them only with :close().

]]
