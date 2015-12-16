--[[

This script is called when MC starts.

It setups the Lua environment and loads system and user scripts.

]]

local internal = require('internal')
local conf = require('conf')

local lua_system_dir, lua_user_dir = conf.dirs.system_lua, conf.dirs.user_lua

package.path =
               -- MC's own modules:
               lua_system_dir .. "/modules/core/?.lua;" ..

               -- User's modules:
               lua_user_dir .. "/modules/?.lua;" ..
               lua_user_dir .. "/modules/?/init.lua;" ..

               -- Distro/Admin's modules:
               lua_system_dir .. "/modules/?.lua;" ..
               lua_system_dir .. "/modules/?/init.lua;" ..

               -- Anything else:
               package.path

require('globals')

------------------------------------------------------------------------------

internal.register_system_callback('mcscript::run_script', function(...)
  return require('mcscript').run_script(...)
end)
internal.register_system_callback('devel::display_error', function(...)
  return require('devel').display_error(...)
end)
internal.register_system_callback('devel::display_abort', function(...)
  return require('devel').display_abort(...)
end)

----------------------------- Auto-loading stuff -----------------------------

local magic = require('utils.magic')

-- Disable casual use of global variables.
magic.setup_strict(_G, true, true)

-- ...and relax it a bit:
declare('bit32')   -- So people can do 'if bit32' to test availability.
declare('jit')     -- ditto.
declare('setfenv') -- ditto.
declare('argv')    -- So people can reference argv even when not using mcscript.
declare('arg')     -- ditto.

magic.setup_autoload(_G)

-- Make it possible to reference builtin modules without 'require'ing them first.
autoload('fs', 'fs')
autoload('mc', 'mc')
autoload('devel', 'devel')
autoload('timer', 'timer')
autoload('event', 'event')
autoload('tty', 'tty')
autoload('ui', 'ui')
autoload('keymap', 'keymap')
autoload('utils', 'utils')
autoload('prompts', 'prompts')
autoload('conf', 'conf')
autoload('locale', 'locale')
autoload('regex', 'regex')

-- Add some juice to strings:
magic.setup_autoload(string)
string.autoload('l_tsplit', {'utils.text', 'tsplit'})
string.autoload('l_split', {'utils.text', 'split'})
require('regex').expose()

-- We can't auto-load the ui module. A comment in 'ui.lua' explains why.
require('ui')

----------------------------------- Timers -----------------------------------

-- Expire unused VFS's.
--
-- (We're calling _vfs_expire every 10 seconds but this number isn't very
-- significant: _vfs_expire in its turn expires, by default, only VFS's
-- not in use for 60 seconds.)
timer.set_interval(fs._vfs_expire, 10*1000)

-- We don't have to call the GC explicitly, but we do, to witness errors
-- in __gc handlers early.
timer.set_interval(function()
  collectgarbage()  -- Should we do "step" instead?
end, 3*1000)

------------------------ Load system and user scripts ------------------------

local function load_all_scripts(dir)

  -- We can shorten this code by using fs.tglob(), but _bootstrap should strive
  -- not to autoload extra modules (which glob/tglob pulls in): this should be
  -- the user's own prerogative.

  -- Note: in the future, if we want to support luac files, it could be done in
  -- package.path alone, for modules. Non-module files don't need this feature.

  local files, failure_reason = fs.dir(dir)

  if not files then
    devel.log(E"I cannot read scripts in this directory: %s":format(failure_reason))
    return
  end

  -- We sort the files alphabetically.
  --
  -- The loading order is, in general, unimportant because we protect the global
  -- namespace and snippets therefore can't mess in each other's guts anyway. But
  -- for things like chaining keyboard.bind(), order does matter.
  --
  -- Nevertheless, we should discourage users from relying on this alphabetic
  -- loading order. We may even decide to remove this "feature" anytime. Users should
  -- instead organize their code in proper modules (and require() them explicitly).
  --
  table.sort(files)

  for _, base in ipairs(files) do
    if base:find "^[^.].*%.lua$" then  -- Exclude files beginning with dot.
      local path = dir .. "/" .. base
      devel.log(E"Loading %s":format(path))
      dofile(path)
    end
  end

end

-- Load the rest of the site.
--
-- We're doing it at a later stage so that possible exceptions there don't
-- halt the rest of this script.
event.bind('core::loaded', function()
  devel.log(":: Loading distro scripts ::")
  load_all_scripts(lua_system_dir)
  devel.log((":: Loading user scripts (%s) ::"):format(lua_user_dir))
  load_all_scripts(lua_user_dir)
  devel.log(":: System loaded ::")
end)

--------------------------- Let users restart Lua ----------------------------

keymap.bind('C-x l', function()
  internal.request_lua_restart()
end)

event.bind('core::before-restart', function()
  -- The user may have initiated the restart because the system is inconsistent.
  -- The pcall() is to turn off exceptions, which are likelier in such state.
  pcall(function()
    prompts.post(T"Restarting Lua...")
  end)
end)

event.bind('core::after-restart', function()
  prompts.flash(T"Lua has restarted!")
end)

------------------------------------------------------------------------------

devel.log(":: Core loaded ::")
