--[[

The functions here are implemented in Lua for the sake of
experimentation, or to save development time.

We may want to move them to the C side at some point.

]]

--- @module regex

local regex = require("c.regex")

local function unpack_(a, b, ...)
  return a, b, {...}
end

---
-- Matches globally.
--
-- Like @{string.gmatch} but uses a regular expression.
--
-- @function gmatch
-- @args (s, regex)
--
function regex.gmatch(subj, patt)

  patt = regex.compile(patt)

  local pos = 1

  return function()

    local start, stop, captures = unpack_(regex.find(subj, patt, pos))
    if not start or start > stop then
      return nil
    end

    pos = stop + 1

    if #captures ~= 0 then
      return table.unpack(captures)
    else
      return subj:sub(start, stop)
    end

  end
end

function regex.expose()
  local string = string

  string.p_find = regex.find
  string.p_match = regex.match
  string.p_gmatch = regex.gmatch
  string.p_gsub = regex.gsub
  string.p_split = regex.split
  string.p_tsplit = regex.tsplit
end

return regex
