--[[

Lets you mark many adjacent files with C-k b, C-k k.

Idea taken from:

    http://www.midnight-commander.org/ticket/3450
    "Quickly tag many adjacent files"

Notes:

This code uses "low level" methods beginning with an underscore.
That's because file indexes is something we've chosen to regard as
"low level", in our panel API.

]]

local start = nil

ui.Panel.bind("C-k b", function(pnl)  -- "Block Beginning"
  start = pnl:_get_current_index()
end)

ui.Panel.bind("C-k k", function(pnl)  -- "Block End"
  if not start then
    return
  end
  local to = pnl:_get_current_index()
  for i = math.min(start, to), math.max(start, to) do
    pnl:_mark_file_by_index(i, true)
  end
  pnl:redraw()
end)

ui.Panel.bind("C-k C-k", function(edt)  -- Invoke the original C-k.
  local ipt = ui.current_widget("Input")
  if ipt then
    if ipt.text == "" then
      alert(T"I think you wanted to press C-k k, not C-k C-k")
    end
    ipt:command "DeleteToEnd"
    ipt:redraw()
  end
end)
