--[[

Often you type "*" at a quicksearch's start to search in the middle of
filenames.

This snippet puts the "*" there automatically for you.

IT TURNS OUT THAT THIS "FEATURE" CAUSES MORE HEADACHE THAN BENEFIT!

]]

ui.Panel.bind('C-s', function(pnl)
  -- We put the code in a timeout so it gets executed after we enter quicksearch mode.
  timer.set_timeout(function()
    pnl:_send_message(ui.MSG_KEY, tty.keyname_to_keycode '*')  -- `('*'):byte()` would work too.
    pnl.dialog:redraw_cursor()
    tty.refresh()
  end, 0)
  return false  -- Continue to default action: start quicksearch.
end)
