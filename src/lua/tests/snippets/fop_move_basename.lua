--[[

Selects the basename of the target file, in the Move/Copy dialogs.

Idea taken from:

    http://www.midnight-commander.org/ticket/2699
    "select only name without extension when renaming"

]]

event.bind('<<dialog::open>>', function(dlg)

  if dlg.text == T'Move' or dlg.text == T'Copy' then

    local ipt = dlg:find('Input', 2)

    if not ipt then
      return  -- it's the progress dialog.
    end

    --
    -- 'fop_move_tail.lua' modifies the input line. If we want to see this
    -- modification we need to postpone ourselves. We do this with a bogus
    -- set_timeout(). Alternatively we could name this file such that it'd
    -- sort alphabtically after 'fop_move_tail.lua' (see comment in
    -- _bootstrap.lua).
    --
    timer.set_timeout(function()

      local s = ipt.text

      local from, to = s:match('.*/().-()%.')  -- matches "/path/to/file.tar.gz"
      if not from then
        from, to = s:match('().-()%.')  -- matches "file.tar.gz"
      end

      if from then
        ipt.mark = from
        ipt.cursor_offs = to
      end

      tty.refresh()  -- because it's in a timer.

    end, 0)

  end

end)
