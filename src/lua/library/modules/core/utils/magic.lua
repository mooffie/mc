---
-- Meta-programming utilities.
--
-- @module utils.magic

local M = {}

---
-- Caches the results of a function call.
--
--    local function heavy(x)
--      return x^(1/3)
--    end
--
--    local light = utils.magic.memoize(heavy)
--
--    -- The following calculates the result just once.
--    print(light(27), light(27), light(27))
--
-- The memoized function may receive several arguments, but as the caching key
-- will serve only the first argument. Thus `light(3, 5)` and `light(3, "whatever")`
-- will give the same result.
function M.memoize(f)
  local lookup = {}
  return function(x, ...)
    local y = lookup[x]
    if y then
      return y
    else
      y = f(x, ...)
      lookup[x] = y
      return y
    end
  end
end

-------------------------------- VB-fication ---------------------------------

local function is_allowed_prop(meta, prop)
  if meta then
    local allowed_properties = meta.__allowed_properties
    return allowed_properties and allowed_properties[prop] or is_allowed_prop(getmetatable(meta), prop)
  end
  -- implicitly return false.
end

local function __getter(tbl, prop)

  local meta = getmetatable(tbl)

  local v = meta[prop]
  if type(v) ~= "nil" then
    return v
  end

  -- We turn the magic on only for instance objects, not for meta tables.
  --
  -- For example, let's assume we have a 'Button' meta table (whose own meta
  -- table may be 'Widget'), and a 'btn' table serving as the actual object
  -- (instance). When we do:
  --
  --    btn.title = "abc"
  --
  -- we want the magic to kick in; as if we typed 'btn.set_title("abc")'.
  -- But when we do:
  --
  --    Button.title = function ...
  --
  -- we don't want any magic.

  local is_instance = not rawget(tbl, "__allowed_properties")
  if is_instance then
    if prop:sub(1,4) ~= "set_" then
      v = meta["get_" .. prop]
      if type(v) == "nil" then
        if not is_allowed_prop(meta, prop) then
          error(E'Property "%s" not found':format(prop), 2)
        end
      else
        return v(tbl)
      end
    end
  end

end

local function __setter(tbl, prop, value)

  local setter = tbl["set_" .. prop]
  if type(setter) == "function" then
    setter(tbl, value)
  else
    -- We turn off magic if it's not an instance (see explanation in __getter).
    local is_instance = not rawget(tbl, "__allowed_properties")
    if (not is_instance) or is_allowed_prop(getmetatable(tbl), prop) then
      rawset(tbl, prop, value)
    else
      error(E'Property "%s" not legal':format(prop), 2)
    end
  end

end

---
-- Enables "syntactic sugar" for properties.
--
-- This facility lets you type (for example):
--
--    obj.title = "abc"
--    print(obj.title)
--
-- instead of:
--
--    obj:set_title("abc")
--    print(obj:get_title())
--
-- An attempt to read/write a property that don't have a getter/setter will
-- be regarded as a typo and an exception will be raised:
--
--    obj.undeclared_property = -666  -- raises exception!
--
-- To allow access to fields without writing getters/setters for them, you
-- need to declare them in the `__allowed_properties` table. Alternatively,
-- use @{rawget}/@{rawset} to access such fields.
--
-- Info: The "vb" in the name of this function stands for "Visual Basic".
-- Since it's a trademark, this function will be renamed as soon as somebody
-- stimulates his neurons enough to come up with a better name.
--
-- This facility is used for @{ui|widgets}. We don't want to encourage its
-- use outside that realm because it's not very conventional. Therefore we
-- don't provide a usage example here (but see @{git:tests/auto/magic_vbfy.mcs}
-- if you want to).
--
-- @param meta The meta table.
function M.vbfy(meta)
  if not rawget(meta, '__allowed_properties') then
    rawset(meta, '__allowed_properties', {})
  end
  rawset(meta, '__index', __getter)
  rawset(meta, '__newindex', __setter)
end

-------------------------- VB-fication for modules ---------------------------

local function __getter_singleton(tbl, prop)
  local getter = rawget(tbl, "get_" .. prop)
  if type(getter) == "nil" then
    error(E'Property "%s" not found':format(prop), 2)
  else
    return getter(tbl)
  end
end

local function __setter_singleton(tbl, prop, value)
  local setter = rawget(tbl, "set_" .. prop)
  if type(setter) == "nil" then
    if type(value) == "function" then
      rawset(tbl, prop, value)
    else
      error(E'Property "%s" not found':format(prop), 2)
    end
  else
    setter(value)
  end
end

---
-- Enables "syntactic sugar" for properties, on modules.
--
-- Like @{vbfy} but works on modules (on tables, to be exact).

function M.vbfy_singleton(module)
  local meta = getmetatable(module) or {}
  meta.__index = __getter_singleton
  meta.__newindex = __setter_singleton
  setmetatable(module, meta)
end

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
-- Protects a function against being called recursively.
--
-- It wraps the function **fn** inside a function that uses locking to
-- ensure that the function is invoked only once in the calling stack.
--
-- See example at @{ui.Panel.load|<<load>>}.
--
-- @function once
-- @args ([lock_name,] fn)

local active_locks = {}

function M.once(lock_name, fn)
  if type(lock_name) == 'function' then
    fn = lock_name
  end
  return function(...)
    if not active_locks[lock_name] then
      active_locks[lock_name] = true
      -- Unless somebody demonstrates that it could be useful, we don't bother
      -- about multiple return values. We return nothing when locked, so there's
      -- no point in being pedantic about the other case.
      local result = fn(...)
      active_locks[lock_name] = nil
      return result
    end
  end
end

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
