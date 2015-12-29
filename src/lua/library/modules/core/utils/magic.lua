---
-- Meta-programming utilities.
--
-- @module utils.magic

local M = {}

------------------------------------------------------------------------------

--
-- Support for "autoloading" and/or "strict" for tables (aka "modules").
--
-- A metatable gets installed for the table.
--
-- The table itself gets:
--
--  t._autoload   Table explaining how to autoload things. Use t.autoload() to
--                populate it.
--
--  t._strict     Table describing the "strict"ing details. Most notably,
--                t._strict.declared lists fields to exclude from "strict"ing.
--                Use t.declare() to populate it.
--

local autoload_meta = {

  __index = function(t, k)
    local how = t._autoload[k]
    if how then
      require('devel.log').log("autoloading " .. k)     -- We must require(). 'devel.log()' would be circular here.

      -- Load the value.
      local value
      if type(how) == "string" then
        -- module.
        value = require(how)
      elseif type(how) == "table" then
        -- function inside a module.
        value = require(how[1])[how[2]]
        if not value then
          error(E"Module '%s' doesn't contain the function '%s'":format(how[1], how[2]))
        end
      elseif type(how) == "function" then
        -- custom value.
        value = how()
      else
        error(E"Invalid autoloading spec.")
      end

      rawset(t, k, value)  -- rawset() so we don't trigger the "strict" protection.
      return value
    elseif not t._strict.read or t._strict.declared[k] then
      return nil
    else
      local msg = (t == _G) and E"Attempting to get an undeclared global variable '%s'."
                            or  E"The module doesn't have a field named '%s'."
      error(msg:format(k),2)
    end
  end,

  __newindex = function(t, k, v)
    if not t._strict.write or t._strict.declared[k] then
      rawset(t, k, v)
    else
      local msg = (t == _G) and E"Attempting to set an undeclared global variable '%s'."
                            -- We don't currently strict-write any module, so the following message isn't really used.
                            or  E"The module is read-only, but you're attempting to create field '%s'."
      error(msg:format(k),2)
    end
  end,

}

local function setup_fancy_meta(t)
   if getmetatable(t) ~= autoload_meta then
     t._autoload = {}
     t._strict = {
       read = false,
       write = false,
       declared = {}
     }
     setmetatable(t, autoload_meta)
   end
end

---
-- Enables autoloading for missing variables.
--
-- You then use `autoload()` to describe how to load the missing values.
--
--    local t = {
--      one = 1,
--      two = 2,
--    }
--
--    utils.magic.setup_autoload(t)
--
--    print(t.m)         -- prints 'nil'
--
--    -- Autoload a module:
--
--    t.autoload('m', 'math')
--
--    print(t.m.cos(0))  -- ok
--
--    -- Autoload a function (of a module):
--
--    t.autoload('cosine', { 'math', 'cos' })
--
--    print(t.cosine(0)) -- ok
--
--    -- Autoload a custom value:
--
--    t.autoload('banner', function()
--      return fs.read('/etc/issue', '*l')
--    end)
--
--    print(t.banner)    -- ok
--
-- Tip: This function returns the magic module itself, and 'autoload()'
-- returns the table itself, thereby allowing for "fluent API":
--
function M.setup_autoload(t)
  setup_fancy_meta(t)
  rawset(t, 'autoload', function(name, how)
    t._autoload[name] = how
    return t  -- allow chaining.
  end)
  return M  -- allow chaining.
end

--- Protects a namespace against referencing missing variables.
--
-- The user may then use `declare()` to allow referencing certain missing
-- variables.
--
--    local t = {
--      one = 1,
--      two = 2,
--    }
--
--    utils.magic.setup_strict(t, true, true)
--
--    print(t.one)    -- ok
--
--    print(t.three)  -- raises exception!
--    t.three = 3     -- raises exception!
--
--    t.declare('three')
--
--    print(t.three)  -- ok
--    t.three = 3     -- ok
--
-- Info: This facility is how the global namespace is protected. See
-- `setup_strict(_G, true, true)` in @{git:core/_bootstrap.lua}.
--
-- Info: This facility is how constants in the @{fs} module are protected
-- against misspellings. E.g., doing `fs.O_RWDR` instead of `fs.O_RDWR`
-- raises an exception.
--
-- Tip-short: This function returns the magic module itself, thereby
-- allowing for "fluent API".
--
function M.setup_strict(t, protect_read, protect_write)
  setup_fancy_meta(t)
  t._strict.read = protect_read
  t._strict.write = protect_write
  rawset(t, 'declare', function(name)
    t._strict.declared[name] = true
  end)
  return M  -- allow chaining.
end

------------------------------------------------------------------------------

---
-- Make __gc for tables work for old Lua engines too.
--
-- Lua 5.2+ supports __gc for table. Older Lua engines don't. To make older
-- Lua engines support it, add a call to `enable_table_gc`:
--
-- Let's first look at a Lua 5.2+ compatible code:
--
--    do
--      local t = setmetatable({},{
--        __gc = function() print("works") end
--      })
--    end
--    collectgarbage()
--
-- To make it work under older Lua engines (Lua 5.1 and LuaJIT), do:
--
--    do
--      local t = setmetatable({},{
--        __gc = function() print("works") end
--      })
--      utils.magic.enable_table_gc(t)
--    end
--    collectgarbage()
--
-- @function enable_table_gc
-- @args (t)
M.enable_table_gc = require('internal').enable_table_gc

return M
