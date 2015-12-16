---
-- Extra string utilities.
--
-- @module utils.text

local M = require("c.utils.text")

---
-- Splits a string into a table.
--
-- The behavior is that of Perl's (and Ruby's) split():
--
-- * Trailing empty fields are removed if __max__ isn't specified. To
--   preserve trailing empty fields, make __max__ negative.
--
-- * If __s__ is the empty string, the result is always an empty list.
--
-- * If the separator isn't specified, the string is split on whitespace
--   runs (with leading whitespaces removed).
--
-- * If the separator matches a zero-length string, the string is split
--   into individual characters (bytes, actually; use @{regex.tsplit} if you
--   want real characters).
--
-- See also @{regex.tsplit}, for a version that uses a Perl-compatible
-- regular expression instead of a Lua pattern.
--
-- @args (s, sep[, max[, is_plain]])
function M.tsplit(s, sep, max, is_plain)
  local prev_stop = 0
  local parts = {}

  -- Perl's perlfunc:
  -- "Note that splitting an EXPR that evaluates to the empty string always returns the empty list, regardless of the LIMIT specified."
  if s == "" then
    return {}
  end

  if not sep then
    sep = "%s+"
    -- Instead of physically trimming the string we skip to the first non-whitespace.
    prev_stop = s:find("%S")
    if not prev_stop then
      return {}
    end
    prev_stop = prev_stop - 1
  end

  local len = s:len()

  while true do
    local pos, stop = s:find(sep, prev_stop + 1, is_plain)
    if pos and ((not max) or (max < 0) or (#parts < max-1)) then
      if pos <= stop then
        -- The normal case.
        parts[#parts+1] = s:sub(prev_stop + 1, pos - 1)
        prev_stop = stop
      else
        -- A zero-length match. In such cases 'stop' is smaller than 'pos':
        --
        --   string.find("whatever", "", 1) gives (1, 0)
        --
        -- We split on every char.
        parts[#parts+1] = s:sub(prev_stop + 1, pos)
        prev_stop = pos
        -- Handle a bug in Lua 5.1: string.find("one", "", 100) doesn't return nil.
        if pos > len then
          break
        end
      end
    else
      parts[#parts+1] = s:sub(prev_stop + 1)
      break
    end
  end

  -- Delete trailing empty fields.
  if not max then
    while parts[#parts] == "" do
       parts[#parts] = nil
    end
  end

  return parts
end

--[[

It should be noted that a simple split can be written in just a few lines. MoonScript's sources have:

  split = (str, delim) ->
    return {} if str == ""
    str ..= delim
    [m for m in str\gmatch("(.-)"..delim)]

]]

---
-- Splits a string.
--
-- This is like @{tsplit} except that the results are returned not in a
-- table but directly:
--
--    first_name, family_name = utils.text.split("John:Doe", ":")
--
-- See also @{regex.split}, for a version that uses a Perl-compatible regular
-- expression instead of a Lua pattern.
--
-- @args (s, sep[, max[, is_plain]])
function M.split(...)
  return table.unpack(M.tsplit(...))
end

local format_number = require('locale').format_number

-- Turns "1234K" into "1,234K" (or however otherwise the locale dictates).
local function format_size__commatize(s)
    local num, units = s:match '^(%d+)(.*)'
    return num and (format_number(num) .. units) or s
end

---
-- Formats a file size.
--
-- Fits the numbers **n**, representing a file size in bytes, in **len**
-- characters. Larger and larger units (kilobytes, megabytes, ...) are
-- tried until the number fits in.
--
-- The optional boolean **comma** parameter tells the function whether to
-- include thousands separators in the result (while still not exceeding
-- **len**). Different locales may cause
-- @{locale.format_number|something other than comma} to actually be used.
--
--    local format_size = utils.text.format_size
--
--    print(format_size(123456789, 9))         -- 123456789
--    print(format_size(123456789, 9, true))   -- 120,563K
--    print(format_size(123456789, 5))         -- 118M
--
-- Whether powers of 1000 or 1024 are used depends on your "Use SI size units"
-- configuration setting.
--
-- See also @{locale.format_number}.
--
-- @function format_size
-- @args (n, len[, comma])
function M.format_size(n, len, comma)
  assert(len > 0)
  local s
  while true do
    s = M._format_size(n, len)
    if comma then
      s = format_size__commatize(s)
    end
    -- When we're asked to add commas, s:len() might exceed 'len'. We
    -- squeeze the number further and further till it fits.
    if s:len() <= len then
      break
    else
      len = len - 1
    end
  end
  return s
end

---
-- Rounds a number.
--
-- Rounds a number **n** to **precision** digits after the point.
-- if **precision** is missing, it's assumed to be 0 (zero).
--
-- @function round
-- @args (n[, precision])

-- Code taken from http://lua-users.org/wiki/SimpleRound
-- But modified to accommodate Lua 5.3.
function M.round(num, idp)
  if not idp or idp == 0 then
    return math.floor(num + 0.5)
  else
    -- The following too works for idp==0, but it returns a float in Lua 5.3
    -- (instead of a desired(?) integer, in the idp==0 case), which is why we
    -- have the seemingly unnecessary branch above.
    local mult = 10^idp
    return math.floor(num * mult + 0.5) / mult
  end
end

local units = {
  { amount = 31536000, title = "Y", round = true }, -- year
  { amount = 2592000,  title = "M", round = true }, -- month
  { amount = 86400,    title = "d", round = true }, -- day
  { amount = 3600,     title = "h", minimum = 5940 }, -- hour; The 'minimum' (99 minutes) makes us get "73 minutes" instead of "1.2 hour".
  { amount = 60,       title = "m", round = true }, -- minute
  { amount = 1,        title = "s", round = true }, -- second
  { amount = 0,        title = "s", round = true }, -- second
}

---
-- Formats a time interval in a compact way.
--
-- Formats a duration given in seconds. The result won't (normally) exceed 3
-- characters (hence "tiny" in the function name). The intention of this
-- function is to make it possible to show dates in places where space is at
-- premium, for example in Panels.
--
-- A letter signifying the units is included in the result: **Y** - years,
-- **M** - months, **d** - days, **h** - hours, **m** - minutes, **s** - seconds.
-- If the interval is negative, a "+" sign is prefixed to the result (so
-- altogether the result may contain 4 characters instead of 3).
--
--    assert(utils.text.format_interval_tiny(60*60*4) == "4h")
--
-- @function format_interval_tiny
-- @args (interval)
function M.format_interval_tiny(interval, skip_rounding)

  local in_the_future = false

  if interval < 0 then
    interval = -interval
    in_the_future = true
  end

  for _, info in ipairs(units) do
    if math.abs(interval) >= (info.minimum or info.amount) then

      local idp = (info.round or not skip_rounding) and 0 or 1   -- how many fractional digit.
      local count = (info.amount == 0) and 0 or M.round(interval / info.amount, idp)

      return (in_the_future and "+" or "") .. count .. info.title
    end
  end
end

---
-- Extracts a word from a string.
--
-- Given a position (byte offset) within a string, returns the word occurring
-- in that position (or nothing, if no word is there). It also returns, as a
-- second value, the part of the word preceding the position.
--
-- Tip: The second value is useful for a "tab completion" feature. The first value
-- is useful for a "spell check this word" feature.
--
-- This function is used to implement @{ui.Editbox.current_word}.
--
function M.extract_word(line, pos, breaks)

  breaks = " \t" .. (breaks or "{}[]()<>=|/\\!?~-+`'\",.;:#$%^&*") -- copied from src/editor/edit.c:is_break_char()

  local breaks_pat = "[" .. breaks:gsub(".", "%%%0") .. "]"

  local after = line:sub(pos, -1)
  local before = line:sub(1, pos - 1):reverse()

  local after_br = after:find(breaks_pat) or (after:len() + 1)
  local before_br = before:find(breaks_pat) or (before:len() + 1)

  local start  = pos - (before_br - 1)
  local finish = pos + (after_br - 2)

  if finish >= start then
    return line:sub(start, finish),
           line:sub(start, pos - 1)
  end

end

require('utils.magic').setup_autoload(M)
M.autoload('transport', 'utils.text.transport')

return M
