--[[

Makes the "Goto line" dialog accept a column too.

Idea taken from:

    http://www.midnight-commander.org/ticket/3195
    "'Goto Line' dialog: goto line:column"

]]

local function goto_line(edt)
  local location = prompts.input(T"Enter line:", nil, T"Goto line", "mc.edit.goto-line")
  if location then
    local line, col = location:match "(%d+)%D+(%d+)"
    if not line then
      line = abortive(location:match "%d+", T"Invalid input!")
      col = 0
    end
    edt.cursor_line = line
    edt.cursor_col = col + 1
  end
end

ui.Editbox.bind('M-l', goto_line)
