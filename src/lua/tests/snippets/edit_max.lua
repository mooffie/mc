
local max_size = 5e6  -- That's 5 megabytes.

ui.Panel.bind("f4", function(pnl)
  local filename, stat = pnl:get_current()
  if stat.size < max_size or prompts.confirm(T"This file is huge. You really want to edit it?") then
    return false
  end
end)

