--[[

Appends the current filename to the destination in the Move/Copy dialogs.

Idea taken from:

    http://www.midnight-commander.org/ticket/1907
    "F5/F6 append filename to path in 'to:' input"

]]

local tail = nil

event.bind('<<dialog::open>>', function(dlg)

  if tail and (dlg.text == T'Move' or dlg.text == T'Copy') then

    local ipt = assert(dlg:find('Input', 2), E"Internal error. I don't see a 'to:' input field here.")
    local new_destination = ipt.text .. tail

    -- We do our magic only if the tweaked destination doesn't
    -- already exist as a directory. Otherwise MC will copy into
    -- it instead of overwriting it.
    if fs.stat(new_destination, 'type') ~= 'directory' then
      ipt.text = new_destination
    end

    tail = nil

  end

end)

ui.Panel.bind('F6', function(pnl)
  if not pnl.marked then
    tail = pnl.current
  end
  return false
end)

ui.Panel.bind('F5', function(pnl)
  if not pnl.marked then
    tail = pnl.current
  end
  return false
end)
