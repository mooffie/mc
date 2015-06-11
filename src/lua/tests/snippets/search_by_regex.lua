-- This snippet is based on the code example given in the documentation for ui.Editbox.cursor_offs.

--[[

Searches in the text.

Incidentally, we have one nice advantage here over the standard search:
we can search for things that sprawl over multiple lines. E.g.,
searching for \n\n\n finds two or more consecutive blank lines.

See also http://www.midnight-commander.org/ticket/400

]]

ui.Editbox.bind("C-d", function(edt)
  local pattern = prompts.input(T"Search by regex:", -1, nil, 'editbox-regex-search')
  if pattern then
    local pos = edt:sub(1):p_find(pattern, edt.cursor_offs + 1)
    if pos then
      edt.cursor_offs = pos
    else
      tty.beep()
    end
  end
end)

--[[

An alternative version which uses less memory:

    local pos = edt:sub(edt.cursor_offs + 1):p_find(pattern)
    if pos then
      edt.cursor_offs = edt.cursor_offs + pos

]]
