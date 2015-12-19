--[[

This file setups the widget classes' "namespaces" (which are their
metatables really).

Currently it only creates constructor functions. E.g., for the Input
class it creates ui.Input().

In the future we will create static functions in each namespace; e.g.,
ui.Input.bind() and ui.Input.subclass().

We're also vbfy()'ing the metatables to enable properties.

]]
--- @module ui

local ui = require("c.ui")
local vbfy, vbfy_singleton  = import_from('utils.magic', {'vbfy', 'vbfy_singleton'})

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

end
