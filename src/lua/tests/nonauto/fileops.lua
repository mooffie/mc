--[[

Tests the 'fileops' (copy/move/delete files).

Symlink it into your user's Lua folder. It overrides the Copy/Move/Delete keys.

]]

local function select_src_trg(pnl, title)
  if not pnl.marked and pnl.current == ".." then
    abort(T"First select the files to work on.")
  end
  local src = pnl.marked or { pnl.current }
  local trg = assert(ui.Panel.other, T"I need to have two panels!").dir
  trg = prompts.input(title:format(#src), trg)
  if trg and trg ~= "" then
    return src, trg
  end
end

ui.Panel.bind('f5', function(pnl)
  local src, trg = select_src_trg(pnl, T"Copy %d file(s) to:")
  if src then
    mc.cp_i(src, trg)
  end
  pnl:reload()
  ui.Panel.other:reload()
end)

ui.Panel.bind('f6', function(pnl)
  local src, trg = select_src_trg(pnl, T"Move %d file(s) to:")
  if src then
    mc.mv_i(src, trg)
  end
  pnl:reload()
  ui.Panel.other:reload()
end)

ui.Panel.bind('f8', function(pnl)
  if not pnl.marked and pnl.current == ".." then
    abort(T"First select the files to work on.")
  end
  local src = pnl.marked or { pnl.current }
  if prompts.confirm(T"Delete %d files?":format(#src)) then
    mc.rm_i(src)
  end
  pnl:reload()
  ui.Panel.other:reload()
end)
