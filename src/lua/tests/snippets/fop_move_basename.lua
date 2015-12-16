--[[

Selects the basename of the target file, in the Move/Copy dialogs.

Idea taken from:

    http://www.midnight-commander.org/ticket/2699
    "select only name without extension when renaming"

Criticism:

This feature can be very uncomfortable in the following situation:

When you want to move files into a subfolder, you may be accustomed to
just typing the folder name and hitting ENTER. But this won't quite work
now: what you type won't replace the whole text but only the basename.
You'll have to delete the whole text first. This can be a nuisance!

]]

ui.Dialog.bind('<<open>>', function(dlg)

  if dlg.text == T'Move' or dlg.text == T'Copy' then

    local ipt = dlg:find('Input', 2)

    if not ipt then
      return  -- it's the progress dialog.
    end

    --
    -- 'fop_move_tail.lua' modifies the input line. If we want to see this
    -- modification we need to postpone ourselves (ui.queue). Alternatively
    -- we could name this file such that it'd sort alphabetically after
    -- 'fop_move_tail.lua' (see comment in _bootstrap.lua).
    --
    ui.queue(function()

      local s = ipt.text

      local from, to = s:match('.*/().-()%.')  -- matches "/path/to/file.tar.gz"
      if not from then
        from, to = s:match('().-()%.')  -- matches "file.tar.gz"
      end

      if from then
        ipt.mark = from
        ipt.cursor_offs = to
      end

    end)

  end

end)
