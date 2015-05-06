--[[

A user complains that the <right> key no longer works in the "Directory
hotlist" dialog:

    http://www.midnight-commander.org/ticket/3221

This snippet fixes this.

]]

ui.Listbox.bind('right', function(lst)
  if lst.dialog.text == T'Directory hotlist' then
    lst.dialog:_send_message(ui.MSG_UNHANDLED_KEY, tty.keyname_to_keycode 'enter')  -- `('\n'):byte()` would work too.
    tty.redraw()
    tty.refresh()
  else
    return false
  end
end)
