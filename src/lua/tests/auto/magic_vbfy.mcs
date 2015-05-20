local ensure = devel.ensure

local vbfy = require('utils.magic').vbfy

local function ensure_meta_has_no_magic(meta, msg)
  ensure.does_not_throw(function()
    meta.Z = 666
    local _ = meta.BOBO
  end, msg)
end


local function ensure_instance_has_magic(instance, msg)
  ensure.throws(function() instance.colsx = 40 end, nil, msg .. ': cannot set illegal property')
  ensure.does_not_throw(function() instance.cols = 40 end, msg .. ': can set legal property')
  ensure.throws(function() return instance.colsx end, nil, msg .. ': cannot get illegal property')
  ensure.does_not_throw(function() return instance.cols end, msg .. ': Can get legal property')
end

local function test()

  local Widget = { cid = "something", get_cols = function() return 20 end, set_cols = function(self, v) print(('setting to %d'):format(v)) end }
  Widget.__index = Widget
  Widget.__allowed_properties = {cent = true}
  vbfy(Widget)

  -- The base meta has no magic because it has **no** meta table.
  ensure_meta_has_no_magic(Widget, 'base meta has no magic')
  ensure_instance_has_magic(setmetatable({}, Widget), 'base instance')

  local Canvas = { colors = "yes", get_pen = function() return "solid" end }
  Canvas.__index = Canvas
  setmetatable(Canvas, Widget)
  vbfy(Canvas)

  -- A derived meta has no magic because of the "is_instance" check.
  ensure_meta_has_no_magic(Canvas, 'derived meta has no magic')
  ensure_instance_has_magic(setmetatable({}, Canvas), 'derived instance')

  local Clock = { analog = "yes!", get_time = function() return "12:30" end }
  Clock.__index = Clock
  setmetatable(Clock, Canvas)
  vbfy(Clock)

  ensure_meta_has_no_magic(Clock, 'derived meta #2 has no magic')
  ensure_instance_has_magic(setmetatable({}, Clock), 'derived instance #2')

end

test()
