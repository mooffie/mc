--[[

This file creates a few class functions (or "static widget functions",
if you will) for each widget type.

E.g., for Input, it creates:

  ui.Input()               (the constructor)
  ui.input.bind()
  ui.input.subclass()

it also vbfy() the metatables.

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

-------------------------------- Subclassing ---------------------------------

--[[-

Creates a new widget class.

For example, let's suppose we want to create a widget that shows the
current time. We can do it thus:

    local clock = ui.Custom()

    function clock:on_draw()
      self.canvas:draw_string(os.date("%H:%M:%S"))
    end

    ui.Dialog():add(clock):run()

However, this widget isn't quite reusable. We can instead create is as a class,

    local ClockMeta = ui.Custom.subclass("Clock")

    function ClockMeta:on_draw()
      self.canvas:draw_string(os.date("%H:%M:%S"))
    end

...and then re-use this class wherever we want:

    ui.Dialog():add(ui.Clock(), ui.Clock(), ui.Clock()):run()

This function, @{subclass}, returns the metatable of the new class. It
also creates the namespace ui.*NewClassName*.

Info: You can initialize your instances in a method called "init". It's
like the constructor from other programming languages.

[tip]

Your new class behaves just like any other widget class. You can even
further inherit from it:

    local RedClock = ui.Clock.subclass("RedClock")

[/tip]

[info]

The namespace also stores the widget's metatable at `meta`. This is true
for all widget classes. You can define new methods on a class easily:

    -- Define a :word_left() method for Editboxes.
    function ui.Editbox.meta:word_left()
      self:command "WordLeft"
    end

[tip]

This `meta` table is very similar to JavaScript's `prototype` property:

    // JavaScript code!
    String.prototype.trim = function() { ... }
    Array.prototype.some = function() { ... }

[/tip]

[/info]

Tip-short: For more examples, see @{git:samples/ui/extlabel.lua} and
@{git:tests/nonauto/ui_subclass.lua}.

@function subclass
@args (new_class_name)

]]

-- Create a new widget class, named 'name', inheriting from 'parent'.
local function subclass(name, parent)

  assert(type(name) == "string", E"The new class name must be a string.")
  assert(parent.meta, E"This doesn't look like a UI class.")
  assert(parent._new, E"Parent class is not designed to be instantiated")

  -- The following is basically what ui-impl.c:create_widget_metatable() does.

  local meta = {}
  meta.__index = meta
  meta.widget_type = name -- Ease debugging.
  setmetatable(meta, parent.meta)

  ui[name] = {
    meta = meta
  }

  -- A constructor function:

  ui[name]._new = function()
    local wgt = parent._new()

    -- Set the correct meta:
    setmetatable(wgt, meta)

    -- Call the correct init(), for any class who wants to use it.
    --
    -- But we call it only if it was defined directly on our meta because we
    -- don't want to end up with some ancestor's init() called twice (as
    -- parent._new() would have already called it).
    if rawget(meta, 'init') then
      wgt:init()
    end

    return wgt
  end

  ui._setup_widget_class(name)

  return meta
end

---------------------------------- Binding -----------------------------------

--- Binds functions to keys and events.
--
-- Use this to execute a function when a certain @{~mod:keymap!key-sequences|key sequence}
-- is pressed in a certain class of widgets:
--
--    ui.Panel.bind('C-y', function(pnl)
--      alert("You're standing on " .. pnl.current)
--    end)
--
-- Or when a certain @{event} occurs:
--
--    ui.Panel.bind('<<load>>', function(pnl)
--      alert("You're browsing " .. pnl.dir)
--    end)
--
-- In both cases the bound function is invoked with the widget as its first
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

local function bind_event(widget_type, event_name, callback)
  event.bind(widget_type:lower() .. "::" .. event_name, callback)
end

------------------------------------------------------------------------------

function ui._setup_widget_class(klass_name)

  local klass = ui[klass_name]
  local meta = klass.meta

  -- VBfy
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
      -- before we even create the dialog object, or else the dialog will be assigned
      -- some fixed default colors.
      if not tty.is_ui_ready() and mc.is_standalone() then
        ui.open()
      end

      local w = t._new()
      return w:assign_properties(props)
    end
  })
  vbfy_singleton(klass)

  klass.bind = function(keyseq_or_event, ...)
    assert(type(keyseq_or_event) == "string", E"string expected as first argument to bind()")
    local event_name = keyseq_or_event:match '^<<(.*)>>$'
    if event_name then
      bind_event(klass_name, event_name, ...)
    else
      bind_key(klass_name, keyseq_or_event, ...)
    end
  end

  klass.subclass = function(new_klass_name)
    assert(new_klass_name, E"You must provide a class name.")
    return subclass(new_klass_name, klass)
  end

end

---
-- @section end
