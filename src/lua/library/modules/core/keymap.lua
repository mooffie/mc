--[[-

Defining global key bindings.

This module is used to define keybindings that are recognized throughout the application:

    keymap.bind('C-a q', function()
      alert("hi!")
    end)

Usually, however, you won't use this module directly but instead call
the @{ui.bind|bind function of a widget class} to restrict the binding to
a certain widget type (often an Editbox or a Panel):

    ui.Listbox.bind('C-a q', function()
      alert("hi from a listbox!")
    end)
    -- One place where you can test this is the
    -- "Directory hotlist" dialog, which contains
    -- a listbox.

The above code is equivalent to:

    keymap.bind('C-a q', {
      fn = function()
        alert("hi from a listbox!!")
      end,
      condition = function()
        -- this effectively returns 'true' if the current
        -- widget is a listbox.
        return ui.current_widget("Listbox")
      end,
      arg = function()
        return ui.current_widget()
      end,
    })
    -- Of course, in practice you won't need to type all
    -- this: simply use ui.Listbox.bind() instead.

We see here that using the 'condition' entry one can make a keybinding
active under a certain condition only. This creates the impression of
having several "keymaps" (one for each widget type). (In reality
there's only one keymap, but you don't need to be aware of this
implementation detail.)

<a name="key-sequences"></a>

## Key sequences

The first argument to `bind()` is a key sequence: it's one or more
@{~mod:tty#keys|key names} separated by a space character. Examples:

- "control-f meta-p home"
- "C-f M-p &lt;home&gt;" (emacs-like syntax is recognized)
- "C-M-x"
- "C-f any"

Info: A special key name is "any", which stands for any key. It can be
used to implement a @{git:screensavers|screensaver} or an abbreviations
utility for the editor. The keycode is passed as the second argument to
the function; see example at @{~mod:ui*widget:fixate}.

<a name="binding-chain"></a>

## Binding chain

You may register several different functions to run for the same key
sequence.

This happens when you call bind() several times, or, more commonly, when you pick a
key already in use by MC.

The *last* function registered whose `condition` is met will be the one
to run. If this function returns an explicit **false**, the lookup will
be resumed with the previously registered function (or, if there's none,
the default action). This little device lets you conditionally override
a default action, as demonstrated at @{~mod:ui.Panel*ui.Panel:current}.

Tip: To help you remember what this explicit **false** does, think of it
as saying "No, dear system, you haven't seen me!"

@module keymap

]]

local M = {}

local CTRL_X = tty.keyname_to_keycode('C-x')

local function new_keymap()
  return { type = 'keymap' }
end

local function is_keymap(o)
  return type(o) == 'table' and o.type == 'keymap'
end

local function new_actions()
  return { type = 'actions' }
end

local function is_actions(o)
  return type(o) == 'table' and o.type == 'actions'
end

------------------------------------------------------------------------------

local bindings = {
  active_map = nil,
  root = new_keymap()
}

bindings.active_map = bindings.root

--[[

The key bindings, which you can see by doing keymap.show(), have the
following structure:

After executing...

  keymap.bind('C-f a', function() ... end)
  keymap.bind('C-f a', ...)
  keymap.bind('C-f b', function() ... end)

...we get:

  {
    root = {
      type = "keymap"

      16390 = {              -- 16390 == Ctrl-F
        type = "keymap"

        97 = {               -- 97 == 'a'
          type = "actions"
          1 = { fn = <function>, condition = <function>, description = "Delete marked files."},
          2 = { fn = <function>, ... }
        }

        98 = {               -- 98 == 'b'
          type = "actions"
          1 = { fn = <function>, ... }
        }
      }
    }
  }

bindings.active_map initially points to root. After pressing Ctrl-F it
points to the '16390' table.

]]

function M.show()  -- For educational/debug purpose only.
  devel.view(bindings)
end

------------------------------------------------------------------------------

--
-- Converts 'C-f a' to {16390, 97}.
--
local function sequence(s)

  local keycodes = {}

  for key in s:gmatch('%S+') do
    -- Note: if you ever modify this code, note that keyname_to_keycode()
    -- returns two values, so if appears as solitary argument in a function
    -- call may cause "bugs". Wrap it in parenthesis to solve this.
    table.insert(keycodes, (key == "any") and "any" or tty.keyname_to_keycode(key))
  end

  return keycodes

end

---
-- Binds a function to a key sequence.
--
-- It its simplest form, the second parameter is the function. It might also be a table
-- with the following fields:
--
-- - fn: the function to run.
-- - condition: the condition to satisfy in order to run,
-- - arg: a function returning an argument to pass to **fn**.
--
-- Indent: In addition to this argument the function will receive another, second
-- argument which is the keycode pressed (this is especially useful when using
-- the [any](#key-sequences) key).
--
-- - description: an optional string describing the action. Isn't currently used. May
--   be used in the future to produce friendly keybinding listings.
--
-- @function bind
-- @args (keyseq, function_or_table)

function M.bind(key_, callback)
  assert_arg_type(1, key_, "string")
  local seq = sequence(key_)
  local last = table.remove(seq)

  if type(callback) ~= "table" then
    callback = { fn = callback }
  end
  assert_arg_type(2, callback.fn, "function")

  -- Drill down to the desired keymap.

  local current = bindings.root
  for _, kcode in ipairs(seq) do
    if not is_keymap(current[kcode]) then
      current[kcode] = new_keymap()
    end
    current = current[kcode]
  end

  -- Add the action.

  if not is_actions(current[last]) then
    current[last] = new_actions()
  end
  -- The most recently bound action is installed first so it gets the
  -- chance to override the previous actions.
  table.insert(current[last], 1, callback)
end

--
-- Handles a key press.
--
-- This is called by MC whenever a key is pressed. We return 'true' to let
-- MC know that we handled the key (and that MC should therefore effectively
-- ignore it).
--
local function keymap_eat(kcode)

  local function process(o)  -- Processes keymap or actions.
    if is_keymap(o) then
      bindings.active_map = o
      local is_mc_prefix = (kcode == CTRL_X and ui.current_widget("Panel"))
      if not is_mc_prefix then
        -- If we have some action bound to, say, "C-u C-q t", we
        -- don't want MC to see either "C-u" or the following "C-q".
        -- There's one exception: Since MC uses "C-x" as a prefix key, we
        -- want it to see it.
        return true
      end
    else
      -- Execute the bound action(s).
      -- Note: we update active_map before calling 'fn' to be re-entrant.
      bindings.active_map = bindings.root
      for _, callback in ipairs(o) do
        if (not callback.condition) or callback.condition() then
          -- If the callback returns an *explicit* 'false', we
          -- continue to the previous callbacks. Otherwise we terminate.
          if callback.fn(callback.arg and callback.arg(), kcode) ~= false then
            return true
          end
        end
      end
      -- No action consumed the key (E.g., all of them returned 'false'). We
      -- implicitly return false.
    end
  end

  -- If the key is registered:
  local active_map_kcode = bindings.active_map[kcode]
  if active_map_kcode and process(active_map_kcode) then
    return true
  end

  -- If the key was not consumed, try "any" too:
  local active_map_any = bindings.active_map["any"]
  if active_map_any and process(active_map_any) then
    return true
  end

  -- If the key breaks sequence, reset to root.
  if not active_map_kcode and not active_map_any then
    bindings.active_map = bindings.root
  end

  -- Implicitly return false.

end

require('internal').register_system_callback("keymap::eat", keymap_eat)

return M
