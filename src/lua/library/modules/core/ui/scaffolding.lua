--[[

This file creates a few class functions (or "static widget functions",
if you will) for each widget type.

E.g., for Input, it creates:

  ui.Input()               (the constructor)
  ui.input.bind()

it also vbfy()'s the metatables to enable properties.

All this work is done by ui._setup_widget_class(), defined here.

]]
--- @module ui

local ui = require("c.ui")
local vbfy, vbfy_singleton  = import_from('utils.magic', {'vbfy', 'vbfy_singleton'})


--[[-

Static widget functions.

You already know that for every widget class there exists a
ui._WidgetClass()_ function that creates ("instantiates") such widget.
E.g., `ui.Input()`.

But ui._WidgetClass_ is also a namespace that groups further functions
and properties. E.g., `ui.Input.bind()`, `ui.Panel.register_field()`,
`ui.Editbox.options`, etc.

This section describes functions common to all widget classes. These
function aren't methods: they're what called in OOP parlance "static".

@section static_widget

]]

---------------------------------- Binding -----------------------------------

--- Binds functions to keys.
--
-- Use this to execute a function when a certain @{~mod:keymap!key-sequences|key sequence}
-- is pressed in a certain class of widgets:
--
--    ui.Panel.bind('C-y', function(pnl)
--      alert("You're standing on " .. pnl.current)
--    end)
--
-- The bound function is invoked with the widget as its first
-- (and only) argument.
--
-- @function bind
-- @args (keyseq_or_event, function)

local function bind_key(widget_type, keyseq, callback)
  if type(callback) ~= "table" then
    callback = { fn = callback }
  end
  callback.condition = function() return ui.current_widget(widget_type) end
  callback.arg = callback.condition
  keymap.bind(keyseq, callback)
end

------------------------------------------------------------------------------

function ui._setup_widget_class(klass_name)

  local klass = ui[klass_name]
  local meta = klass.meta

  -- Enable properties for widget instances: lets you type input.text instead of input:get_text().
  vbfy(meta)

  -- Lua 5.2+ must have the __gc directly on the table, it can't be inherited, so:
  if not rawget(meta, '__gc') then
    -- 'meta.__gc' typically fetches either ui.Dialog.meta.__gc or ui.Widget.meta.__gc.
    rawset(meta, '__gc', meta.__gc)
  end

  -- Create a ui.Klass() constructor.
  setmetatable(klass, {
    __call = function(t, props)

      if not rawget(t, '_new') then
        error(E"This widget is not designed to be instantiated.")
      end

      -- If we're in standalone mode, launch the UI.
      --
      -- A more natural place to put this might seem to be in dialog:run(),
      -- but it's important to initialize the color subsystem (the skin)
      -- before we even create the dialog object, or else the dialog will be
      -- assigned some fixed default colors (UPDATE: starting with commit
      -- bf474e this is no longer an issue as dialogs now hold a *pointer* to
      -- the color table, not the table itself).
      if not tty.is_ui_ready() and mc.is_standalone() then
        ui.open()
      end

      local w = t._new()
      return w:assign_properties(props)
    end
  })

  -- Enable static properties: lets you type ui.Panel.left instead of ui.Panel.get_left().
  vbfy_singleton(klass)

  klass.bind = function(keyseq, ...)
    assert(type(keyseq) == "string", E"string expected as first argument to bind()")
    bind_key(klass_name, keyseq, ...)
  end

end

---
-- @section end
