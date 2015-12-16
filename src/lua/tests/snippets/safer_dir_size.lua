--[[

Safer C-space.

A user complains that C-space (for calculating directory sizes) doesn't
unmark the directories after operation, thereby leading to possible
accidental deletion/moving/etc.:

    http://www.midnight-commander.org/ticket/3551

To solve this, this snippet:

(1) Defines C-space to unmark the files afterwards.

(2) For whoever wants it, we define F3 to behave similarly to the old
    C-space with the added feature --as in Dos Navigator and FAR-- that
    the cursor doesn't move down.

]]


ui.Panel.bind('C-space', function(pnl)
  pnl.dialog:command 'DirSize'
  pnl.marked = {}
end)


ui.Panel.bind('f3', function(pnl)

  local fname, stat = pnl:get_current()

  if stat.type == 'directory' then
    local cur = pnl.current
    pnl.dialog:command 'DirSize'
    pnl.current = cur  -- Restore original position.
  else
    -- If we're standing on a normal file, proceed to
    -- the default action.
    return false
  end

end)
