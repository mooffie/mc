
---------- The "Clock" widget --------------------

local ClockMeta = ui.Custom.subclass("Clock")

ClockMeta.__allowed_properties = {
  -- We have to declare fields we use. See doc for utils.magic.vbfy().
  _itvl = true
}

function ClockMeta:preferred_cols()
  return ("00:00:00"):len()
end

function ClockMeta:preferred_rows()
  return 1
end

function ClockMeta:on_draw()
  local c = self:get_canvas()
  c:erase()
  c:draw_string(os.date("%H:%M:%S"))
end

function ClockMeta:tick()
  self:redraw()
  self.dialog:redraw_cursor()  -- Move the cursor back to the right widget.
  tty.refresh()
end

function ClockMeta:init()
  self._itvl = timer.set_interval(function()
    if self:is_alive() then
      self:tick()
    else
      -- The dialog has been destroyed.
      --
      -- The timer keeps ticking, however. So we stop it. The minor reason
      -- is to conserve CPU cycles. The bigger reason is to enable the Lua
      -- widget to be garbage-collected: the timer function (it's the one
      -- you're looking at right now) contains a reference to 'self', which
      -- prevents it from being GC'ed.
      self._itvl:stop()
    end
  end, 1000)
end

---------- The "RedClock" widget --------------------

local RedClockMeta = ui.Clock.subclass("RedClock")

function RedClockMeta:on_draw()
  self:get_canvas():set_style(tty.style('red, white'))
  -- Note: make sure not to do 'ClockMeta:on_draw()' instead of 'ClockMeta.on_draw(self)':
  -- it's *not* the metatable that's the 'self'.
  ClockMeta.on_draw(self)
end

------------------------------


local function test()

  local dlg = ui.Dialog("Subclassing")

dlg:add(ui.Label(
[[This example demonstrates subclassing. We define a "Clock" class
and instantiate it twice. We also define a "RedClock" class, inheriting
from "Clock", and it too we instantiate twice.

You may type something into the input box to verify that the cursor
doesn't "go away" when the clocks tick.]]))

  dlg:add(ui.ZLine())

  dlg:add(ui.Input())

  dlg:add(ui.HBox():add(ui.Clock(), ui.Clock()))
  dlg:add(ui.HBox():add(ui.RedClock(), ui.RedClock()))

  dlg:add(ui.DefaultButtons())

  dlg:run()
end


test()
--[[
keymap.bind('f4', test)
keymap.bind('f5', function()
  devel.view( debug.getregistry()['ui.weak']  )
end)
]]
