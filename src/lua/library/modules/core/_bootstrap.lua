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

------------------------------ Pre-loading stuff -----------------------------

-- Make it possible to use the builtin modules without 'require'ing them first.
locale = require('locale')

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
    print((":: Loading user script (%s) ::"):format(user_script))
    dofile(user_script)
  else
    print((":: User script not found (%s) ::"):format(user_script))
  end
end

load_user_scripts()

------------------------------------------------------------------------------

print(":: Core loaded ::")
