--[[

Some useful keybindings.

Usage:

    require('samples.accessories.tabs.default-key-bindings')

]]

local tabs = require('samples.accessories.tabs.core')

ui.Panel.bind('M-<', function()
  tabs.tab_left()
end)

ui.Panel.bind('M->', function()
  tabs.tab_right()
end)
