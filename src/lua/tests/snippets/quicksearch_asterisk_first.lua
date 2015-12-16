--[[

Often you type "*" at a quicksearch's start to search in the middle of
filenames.

This snippet puts the "*" there automatically for you.

Criticism:

IT TURNS OUT THAT THIS "FEATURE" CAUSES MORE HEADACHE THAN BENEFIT!

]]

ui.Panel.bind('C-s', function(pnl)
  -- We postpone the code so it gets executed after we enter quicksearch mode.
  ui.queue(function()
    pnl:_send_message(ui.MSG_KEY, tty.keyname_to_keycode '*')  -- `('*'):byte()` would work too.
    pnl.dialog:redraw_cursor()
  end)
  return false  -- Continue to default action: start quicksearch.
end)
