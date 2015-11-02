--[[

Improved Syntax highlighting for Lua.

It just adds a few function & field names.

]]

ui.Editbox.bind('<<load>>', function(edt)

  if edt.syntax ~= "Lua Program" and edt.syntax ~= "LUA Program"then
    return
  end

  local styles = {
    api      = tty.style 'yellow',
    special  = tty.style 'magenta,,bold',
  }

  local function api(name)       edt:add_keyword(name, styles.api)        end
  local function special(name)   edt:add_keyword(name, styles.special)    end

  api 'load'
  api 'select'
  api 'coroutine.running'
  api 'debug.getregistry'

  api 'table.pack'
  api 'table.maxn'
  api 'table.unpackn'

  special 'io.stderr'
  special 'io.stdin'
  special 'io.stdout'
  special 'package.path'
  special 'math.pi'

end)
