
local last_pattern = nil

--
-- Search in the text.
--
-- (Code mostly taken from the example code for the ui.Editbox.cursor_offs
-- property.)
--
-- We have one nice advantage here over the standard search:
-- we can search for things that sprawl over multiple lines. E.g.,
-- searching for \n\n\n finds two or more consecutive blank lines.
--
-- See also http://www.midnight-commander.org/ticket/400
--
ui.Editbox.bind("C-d", function(edt)
  local pattern = prompts.input(T"Search by regex:", last_pattern, nil, 'editbox-regex-search')
  if pattern then
    last_pattern = pattern
    local pos = edt:sub(1):p_find(pattern, edt.cursor_offs + 1)
    if pos then
      edt.cursor_offs = pos
    else
      tty.beep()
    end
  end
end)