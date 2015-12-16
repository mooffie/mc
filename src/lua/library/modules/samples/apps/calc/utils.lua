--[[

A few utility functions to convert integers to binary, octal, hex.

The conversion functions assume the input is lua_Integer, so you should
use M.tointeger() first.

This file is a tad complicated because we want to support negative
numbers.

]]

local M = {}

--
-- Whether string.format("%x") can accept negative numbers.
-- Lua 5.2 fails this (Lua 5.1 and 5.3 are ok).
--
local unrestrictive_format_x = pcall(function()
  string.format('%x', -1)
end)

local uint32_cast = utils.bit32.band  -- A trick utilizing band()'s input/output range.

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

--
-- Shows the binary representation of a Lua integer. That is, the
-- counterpart for "%x".
--
-- (This is customarily done by repeatedly taking the right-most bit ("1" or
-- "0") and dividing the number by two. But we want something that works
-- for negatives and is clipped to lua_Integer's range.)
--
function M.tobinary(i)

  local hex = M.tohex(i)

  local bin = hex
    :gsub('.', bits)  -- the conversion itself.
    :gsub('^0+(.)', '%1') -- get rid of zeroes at the left (except a solitary one).

  return bin

end

function M.tohex(i)
  return string.format('%x', unrestrictive_format_x and i or uint32_cast(i))
end

function M.tooct(i)
  return string.format('%o', unrestrictive_format_x and i or uint32_cast(i))
end

--
-- Converts lua_Number to lua_Integer (or to nil if it's not possible).
--
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
  --
  -- We assume lua_Integer is 32 bits.
  function M.tointeger(n)

    local i = nil

    if n < 0 then
      if n >= -0x7fffffff - 1 then  -- If the number is smaller than -2,147,483,648, we can't represent it! We have only 32 bits.
        i = -uint32_cast(-n)
      end
    else
      i = uint32_cast(n)
    end

    if i ~= math.modf(n) then
      -- Overflow.
      return nil
    else
      return i
    end

  end

end

function M.baseconv(s, base, errmsg)
  s = type(s) == "string" and s:gsub('[_ ]','') or s
  return tonumber(s, base) or error(errmsg:format(s))
end

return M
