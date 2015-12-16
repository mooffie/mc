--[[

Marks C functions.

Stand in its body and hit C-c b.

]]

ui.Editbox.bind('C-c b', function(edt)

  local y1 = edt.cursor_line

  while y1 > 1 and edt:get_line(y1):p_find [[^([\s#]|$)]] do
    y1 = y1 - 1
  end
  while y1 > 2 and edt:get_line(y1-1):p_find [[^\S]] do
    y1 = y1 - 1
  end

  local y2 = edt.cursor_line
  local max = edt.max_line

  while y2 < max and edt:get_line(y2):p_find [[^([\s#]|$)]] do
    y2 = y2 + 1
  end

  edt:command "home"
  edt.cursor_line = y2 + 1
  edt:command "mark"
  edt.cursor_line = y1
  edt:command "mark"

end)
