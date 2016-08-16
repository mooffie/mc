--[[

Support for "Lynx-like motion" in the panels.

Installation:

    require('samples.accessories.lynx-keys')

About:

MC already has this feature built-in (see "Panel options..." dialog) but
ours has two additional features:

- Pressing <right> over a directory also positions you on its first file.

- Pressing <right> over a normal file "runs" it. It's like pressing ENTER.

]]

ui.Panel.bind_if_commandline_empty('left', function(pnl)
  pnl:command 'CdParent'
  pnl:redraw()
end)

ui.Panel.bind_if_commandline_empty('right', function(pnl)
  local fname, stat = pnl:get_current()
  if stat.type == 'directory' then
    pnl:command 'CdChild'
    pnl:command 'down'
  else
    pnl:command 'enter'
  end
  pnl:redraw()
end)
