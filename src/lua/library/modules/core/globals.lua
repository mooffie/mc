---
-- Globals functions.
--
-- Info: There isn't really a module named "globals". This page just serves to
-- document any global functions or variables.
--
-- @pseudo
-- @module globals

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

------------------------------------------------------------------------------
-- Lua compatibility.
--
-- These are functions that were either removed or added in Lua 5.2+. We
-- implement them so they're always available.
--
-- @section compat

---
-- @function table.unpack
if not table.unpack then
  table.unpack = unpack
  unpack = nil
end

---
-- @function table.pack
if not table.pack then
  function table.pack(...)
    return { n = select('#', ...), ... }
  end
end

---
-- @function table.maxn
if not table.maxn then
  function table.maxn(t)
    local max = 0
    for k in pairs(t) do
      if type(k) == 'number' and k > max then
        max = k
      end
    end
    return max
  end
end

---
-- This function is our own's extension to the API. It's equivalent to
-- `table.unpack(t, 1, t.n or table.maxn(t))`. It's a version of
-- `table.unpack` which is tolerant to `nil`s.
--
-- @function table.unpackn
function table.unpackn(t)
  return table.unpack(t, 1, t.n or table.maxn(t))
end

------------------------------------------------------------------------------
