--[[

This script is called when MC starts.

It setups the Lua environment and loads system and user scripts.

]]

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
autoload('devel', 'devel')
autoload('tty', 'tty')
autoload('utils', 'utils')
autoload('conf', 'conf')
autoload('locale', 'locale')

----------------------------- Load user scripts ------------------------------

-- A primitive way to check for a file's existence. We'll replace it once we can.
local function file_exists(path)
  local f = io.open(path)
  if f then
    f:close()
    return true
  end
end

-- Load user scripts.
--
-- We load only 'index.lua', from the user dir. The user can require() other
-- scripts from there.
--
local function load_user_scripts()
  local user_script = lua_user_dir .. "/index.lua"
  if file_exists(user_script) then
    devel.log((":: Loading user script (%s) ::"):format(user_script))
    dofile(user_script)
  else
    devel.log((":: User script not found (%s) ::"):format(user_script))
  end
end

load_user_scripts()

------------------------------------------------------------------------------

devel.log(":: Core loaded ::")
