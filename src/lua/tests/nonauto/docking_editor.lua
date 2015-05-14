--[[

Tests the editor docker.

]]

local docker = require('samples.libs.docker-editor')

local _cnt = 0
local function counter()
  _cnt = _cnt + 1
  return _cnt
end

docker.register_widget('south', function()
  return ui.Label('South' .. counter())
end)

docker.register_widget('north', function()
  return ui.Label('North' .. counter())
end)

docker.register_widget('east', function()
  return ui.Label('East' .. counter())
end)

docker.register_widget('west', function()
  return ui.Label('West' .. counter())
end)
