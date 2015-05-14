--[[
This module exposes one function, eval(), which evaluates a string within a given environment.
]]

local M = {}

local function compile_string(s, env)
  local fn, errmsg

  if setfenv then
    -- Lua 5.1
    fn, errmsg = loadstring(s, '[input]')
    if fn then
      setfenv(fn, env)
    end
  else
    -- Lua 5.2+
    fn, errmsg = load(s, '[input]', 't', env)
  end

  return fn, errmsg
end

local function pretty_error(errmsg)
  local gist = errmsg:match(':%d+:%s+(.*)') or errmsg
  -- The following is stolen from Lua's lua.c:incomplete(). It's how
  -- the 'lua' executable detects incomplete input.
  if gist:find '<eof>.?$' then
    gist = T"Incomplete input"
  end
  return gist
end

function M.eval(s, env)
  local fn, errmsg

  for _, prefix in ipairs { "return ", "" } do
    if not fn then
      fn, errmsg = compile_string(prefix .. s, env)
    end
  end

  if not fn then
    -- Compilation error.
    return nil, pretty_error(errmsg)
  else
    local success, results = pcall(function() return {fn()} end, env)
    if success then
      return results, nil
    else
      -- Run-time error.
      --
      -- "results" here is the error message. In case it's not a
      -- string (e.g., 'error {}'), we first convert it to one.
      return nil, pretty_error(tostring(results))
    end
  end
end

return M
