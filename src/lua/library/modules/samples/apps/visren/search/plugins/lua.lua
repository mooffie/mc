-- Searching using a Lua pattern.
--
-- It supports neither UTF-8 nor case-insensitive search. It was written when
-- MC/Lua didn't have regex support. But now there's little reason to use it.
-- It remains because it can serve an educational purpose (teaching users about
-- Lua patterns).

local M = {
  title = T"&Lua pattern",
}

M.does_match = function(s, r)
  return string.find(s, r)
end

M.find = function(s, r, idx)
  return string.find(s, r, idx)
end

M.compile_template = function(t)
  return t
end

-- Validates a Lua pattern.
--
-- Lua doesn't compile patterns, and therefore we don't know about pattern
-- errors till we encounter them while matching. That isn't good for us, so
-- here we validate a Lua pattern ourselves.
local function validate(s)
  local level = 0
  while s:len() > 0 and level >= 0 do
    if s:find("^%%b..") then           -- %b..
      s = s:sub(5)
    elseif s:find("^%%f%[") then       -- %f[
      s = s:sub(3)
    elseif s:find("^%%.") then         -- %.  (when not 'b' or 'f')
      local c = s:sub(2,2)
      if c == "b" then
        return nil, "unfinished %bxy"
      end
      if c == "f" then
        return nil, "missing [ after %f"
      end
      s = s:sub(3)
    elseif s:find("^%[.-[^%%]]") then   -- [.-]
      local a, b = s:find("^%[.-[^%%]]")
      s = s:sub(b+1)
    elseif s:find("^%(") then           -- (
      level = level + 1
      s = s:sub(2)
    elseif s:find("^%)") then           -- )
      level = level - 1
      s = s:sub(2)
    elseif s:find(".") then
      local c = s:sub(1,1)
      if c == '%' then
        return nil, "ends with %"
      end
      if c == '[' then
        return nil, "missing ]"
      end
      s = s:sub(2)
    end
  end

  if level > 0 then
    return nil, "missing terminating )"
  elseif level < 0 then
    return nil, ") without opening ("
  else
    return true
  end
end

M.compile_re = function(pat)
  local ok, errmsg = validate(pat)
  if ok then
    return pat
  else
    return nil, errmsg
  end
end

return M
