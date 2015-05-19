--[[-

Responding to global events.

This module lets you run some code when a global event is triggered:

    -- Sound a beep whenever Lua is restarted.
    event.bind('core::after-restart', function()
      os.execute('beep -l 4')
    end)

Often, however, you won't use this module directly but instead call the
@{ui.bind|bind function of a widget class} (when the event is
widget-related). This serves only a stylistic purpose: it makes the
syntax of binding events the same as that of @{keymap|binding keys}:

    ui.Panel.bind('<<load>>', function(pnl)
      devel.log('The ' .. pnl.dir .. ' directory has been read.')
    end)

Note that here we wrap the event name in "&lt;&lt;" and "&gt;&gt;" (a
syntax borrowed from the Tk toolkit). Otherwise it'd look like a key
name to the system.

The above code is equivalent to:

    event.bind('Panel::load', function(pnl)
      devel.log('The ' .. pnl.dir .. ' directory has been read.')
    end)
    -- But please refrain from writing such code. Use ui.Panel.bind() instead.

@module event

]]

local event = {}

local bindings = {}

local append = table.insert

---
-- Binds a function to some event.
function event.bind(event_name, fn)
  -- While we use <<event-name-in-brackets>> in documentation, the event
  -- name doesn't really have these brackets.
  if event_name:find '^<' then
    event_name = event_name:gsub('^<<', ''):gsub('>>$', '')
  end

  if not bindings[event_name] then
    bindings[event_name] = {
      callbacks = {}
    }
  end

  append(bindings[event_name].callbacks, fn)
end

---
-- Triggers an event.
--
-- While you may use this to simulate a system event, usually you'd find
-- it more useful to trigger you own events:
--
--    event.bind('pacman::apple-eaten', function()
--      mc.activate('/path/to/apple-eaten.wmv')
--    end)
--
--    event.trigger('pacman::apple-eaten')
--
-- (You don't need to "declare" (or "register") your events before using
-- them. One drawback, though, is that typos in event names aren't caught.)
--
-- Above we used a "component::detail" syntax for the event name, but that's
-- not mandatory.
--
-- @param event_name
-- @param ... Optional arguments to pass to bound functions.
function event.trigger(event_name, ...)
  local callbacks = bindings[event_name] and bindings[event_name].callbacks
  if callbacks then
    for _, fn in ipairs(callbacks) do
      fn(...)
    end
  end
end

require('internal').register_system_callback("event::trigger", event.trigger)

return event
