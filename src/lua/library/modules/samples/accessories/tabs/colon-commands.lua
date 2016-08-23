--[[

Implements a few "colon" commands.

Usage:

    require('samples.accessories.tabs.colon-commands')

]]

local colon = require('samples.colon')
local tabs = require('samples.accessories.tabs.core')

colon.register_command {
  name = 'tc',
  fn = function()
    tabs.close_tab()
  end,
  desc = T[[
Close the current tab.]],
}

colon.register_command {
  name = 'tr',
  synopsis = 'tr [name]',
  fn = function(_, name)
    tabs.rename_tab(name)
  end,
  desc = T[[
Rename the current tab.]],
}

colon.register_command {
  name = 'tn',
  synopsis = 'tn [name]',
  fn = function(_, name)
    tabs.create_tab(name)
  end,
  desc = T[[
New tab.]],
}

colon.register_command {
  name = 'td',
  fn = tabs.show_debugging_info,
  desc = T[[
Show tabs debugging info.]],
}
