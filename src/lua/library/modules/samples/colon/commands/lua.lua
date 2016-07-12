--
-- Lua-related commands.
--

local colon = require('samples.colon')

colon.register_command {
  name = 'source',
  alias = '.',
  fn = function(_, script_file)
    abortive(script_file, T"You need to name the file to load.")
    abortive(fs.file_exists(script_file))
    -- The user may be browsing a snippets archive or an FTP so
    -- we localize the file first (dofile() is Lua's own, so doesn't
    -- support the VFS).
    local lcl_script_file = fs.getlocalcopy(script_file)
    dofile(lcl_script_file)
    fs.ungetlocalcopy(script_file, lcl_script_file, false)
  end,
  synopsis =
    "source <lua-script>\n" ..
    ". <lua-script>",
  desc = T[[
Loads a Lua script.
You can use this to load various Lua snippets. You'll see an error
message if there's some syntax error (or runtime error) in the file.
Don't panic: just fix the problem and repeat.]],
}

colon.register_command {
  name = 'restart',
  fn = function()
    require('internal').request_lua_restart()
  end,
  desc = T[[
Restarts Lua.
This brings the system to the state right after MC starts. Useful when
you modify a module and need it reloaded, or when you screw up something.]],
}
