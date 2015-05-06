
local M = {}


--[[

Shows the binary representation of a Lua integer. That is, the
counterpart for "%x".

(This is customarily done by repeatedly taking the right-most bit ("1" or
"0") and dividing the number by two. But we want something that works
for negatives and is clipped to lua_Integer's range.)

]]

local bits = {
 ['0'] = '0000',
 ['1'] = '0001',
 ['2'] = '0010',
 ['3'] = '0011',
 ['4'] = '0100',
 ['5'] = '0101',
 ['6'] = '0110',
 ['7'] = '0111',
 ['8'] = '1000',
 ['9'] = '1001',
 ['a'] = '1010',
 ['b'] = '1011',
 ['c'] = '1100',
 ['d'] = '1101',
 ['e'] = '1110',
 ['f'] = '1111',
}

function M.tobinary(n)

  local hex = string.format('%x', n)

  local bin = hex
    :gsub('.', bits)  -- the conversion itself.
    :gsub('^0+(.)', '%1') -- get rid of zeroes at the left (except a solitary one).

  return bin

end


-- Converts lua_Number to lua_Integer (or to nil if it's not possible).
if math.tointeger then

  -- Lua 5.3+
  function M.tointeger(n)
    -- We can't just do math.modf(n) (or math.floor(n)) because it may return
    -- a lua_Number (if n isn't in lua_Integer's range).
    --
    -- We can't just do math.tointeger(n) either because it'd return nil
    -- for '3.4'.
    --
    -- So we combine the two.
    return math.tointeger(math.modf(n))
  end

else

  -- Older Lua.
  function M.tointeger(n)
    if string.format('%x', n) == '0' and math.abs(n) > 1.0 then
      -- Overflow.
      return nil
    else
      return math.modf(n)
    end
  end

end

function M.baseconv(s, base, errmsg)
  s = type(s) == "string" and s:gsub('[_ ]','') or s
  return tonumber(s, base) or error(errmsg:format(s))
end

return M
