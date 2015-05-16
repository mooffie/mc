---
-- Globals functions.
--
-- Info: There isn't really a module named "globals". This page just serves to
-- document any global functions or variables.
--
-- @pseudo
-- @module globals


-- Lua 5.2 compatibility.
if not table.unpack then
  table.unpack = unpack
  unpack = nil
end

----------------------------- defined elsewhere ------------------------------

---
-- Alias for @{prompts.alert}.
-- @function alert
-- @args

---
-- Defined @{locale.T|at the locale module}.
-- @function T
-- @args

---
-- Defined @{locale.N|at the locale module}.
-- @function N
-- @args

---
-- Defined @{locale.Q|at the locale module}.
-- @function Q
-- @args

---
-- Defined @{locale.E|at the locale module}.
-- @function E
-- @args

------------------------------------------------------------------------------

---
-- A "benign" version of @{error}.
--
-- Instead of showing the error message in a frightening red box with a stack
-- trace, it's shown as a normal @{alert}. This is intended for usage errors
-- whereas @{error} is intended for programming errors.
--
function abort(message)
  error {
    abort=true,
    message=message
  }
end

---
-- A "benign" version of @{assert}.
--
-- See @{abort}.
--
function abortive(val, message, ...)
  if val then
    return val, message, ...
  else
    abort(message)
  end
end

---
-- A utility for validating types of function arguments.
--
-- Example:
--
--    function print_message(msg)
--      assert_arg_type(1, msg, "string")
--      ...
--    end
--
-- @function assert_arg_type
-- @args (idx, val, type)
function assert_arg_type(idx, val, xtype)
   if type(val) ~= xtype then
     error(
       E"A %s is expected as argument #%d, but a %s was provided instead.":format(
         xtype, idx, type(val)
       ), 2
     )
   end
end

---
-- Declares global variables.
--
-- You @{~general#global|won't normally use global variables}, but if
-- you have to, you first have to declare them:
--
--    declare('foo')
--    foo = 666
--
-- @function declare
-- @args (variable_name)

--- Imports names from a module.
--
-- This is just a convenience function. Instead of doing the lengthy:
--
--    local stamp = assert(require('luafs.gc').stamp)
--    local rmstamp = assert(require('luafs.gc').rmstamp)
--    local stamp_create = assert(require('luafs.gc').stamp_create)
--    -- The assert() guards against typos.
--
-- Do:
--
--    local stamp, rmstamp, stamp_create
--        = import_from('c.luafs', { 'stamp', 'rmstamp', 'stamp_create' })
--
function import_from(module_name, names)
  local ret = {}
  local module = require(module_name)
  for _, name in ipairs(names) do
    if not module[name] then
      error(E"The name '%s' isn't exposed by the module '%s'.":format(name, module_name))
    end
    ret[1 + #ret] = module[name]
  end
  return table.unpack(ret)
end

---
-- Requires a legacy module.
--
-- This is like @{require} except that it turns off the global namespace
-- protection during its operation so old code which sets global variable(s)
-- won't raise an exception.
--
-- @function require_legacy
-- @args (module_name)
function require_legacy(module_name)
  require('utils.magic').setup_strict(_G, false, false)
  local mod = require(module_name)
  require('utils.magic').setup_strict(_G, true, true)
  return mod
end

------------------------------------------------------------------------------
-- Command line arguments.
--
-- A table holding command line arguments, starting at index 1. Index 0
-- holds the pathname of the script being run.
--
-- It is only available in @{mc.is_standalone|standalone} mode. Otherwise
-- it is **nil**. See the @{~standalone|user guide} for details.
--
-- See usage example in @{git:misc/bin/htmlize}
--
-- @field argv

--- Alias for `argv`.
--
-- [info]
--
-- This alias exists for compatibility with source code written for
-- `/usr/bin/lua`, the "official" Lua interpreter, which names that table "arg".
--
-- You should prefer using "argv" in your code because grepping your code
-- for this name is easier ("arg", on the other hand, is a more generic term).
--
-- [/info]
--
-- @field arg

arg = argv

------------------------------------------------------------------------------
-- Events
-- @section

--- Triggered when the UI has become @{tty.is_ui_ready|ready}.
--
-- @moniker ui::ready
-- @event

--- Triggered when the UI is restored.
--
-- Whenever a user returns from running a shell command, or resumes a
-- suspended MC process, the UI is restored.
--
-- For example, the @{git:screensavers/utils.lua|screensaver} uses this
-- event to reschedule the animation.
--
-- @moniker ui::restored
-- @event

--- Triggered when the user changes the skin.
--
-- See explanation in @{tty.style}.
--
-- @moniker ui::skin-change
-- @event

--- Triggered after Lua has been restarted (e.g., by pressing `C-x l`, by default).
--
--    -- Sound a beep so the user knows Lua's been
--    -- restarted successfully.
--    event.bind('core::after-restart', function()
--      os.execute('beep -l 4')
--    end)
--
-- See also @{core::before-restart}.
--
-- @moniker core::after-restart
-- @event

--- Triggered just before Lua gets restarted.
--
-- See also @{core::after-restart}.
--
-- @moniker core::before-restart
-- @event

---
-- [Used internally].
--
-- Note-short: End-users won't need this.
--
-- Triggered after the core's @{git:_bootstrap.lua} script has run. It's
-- used by the system to initiate the loading of user and system scripts.
--
-- @moniker core::loaded
-- @event

---
-- [Used internally].
--
-- Note-short: End-users won't need this.
--
-- @moniker core::before-vfs-shutdown
-- @event

---
-- Triggered after MC layouts the filemanager dialog.
--
-- This event lets the @{git:docker.lua|docker} module add widgets there.
--
-- Note-short: In the future we'll replace this event by, possibly, `dialog::resize`.
--
-- @moniker filemanager::layout
-- @event

---
-- @section end

------------------------------------------------------------------------------
