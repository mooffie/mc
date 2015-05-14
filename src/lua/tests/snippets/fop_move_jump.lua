--[[

Tracks a renamed file.

In other words: after standing on "file1.c" and renaming it to "zoro.c",
we'll be repositioned to stand on "zoro.c".

Idea taken from:

    http://www.midnight-commander.org/ticket/1684
    "Rename operation behaviour is not natural to file managers"

]]

ui.Panel.bind('F6', function(pnl)
  local original_ino = pnl.current_ino
  pnl.dialog:command "Move"
  pnl.current_ino = original_ino
end)

ui.Panel.bind('F16', function(pnl)
  local original_ino = pnl.current_ino
  pnl:command "MoveSingle"
  pnl.current_ino = original_ino
end)

-- Returns the inode # of the current file.
function ui.Panel.meta:get_current_ino()
  local _, stat = self:get_current()
  return stat.ino
end

-- Sets the current file to the one having a certain inode #.
function ui.Panel.meta:set_current_ino(i)
  for fname, stat in self:files() do
    if stat.ino == i then
      self.current = fname
      break
    end
  end
end
