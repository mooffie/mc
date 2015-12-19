--[[-

Table utilities.

There are two ways to call these functions. Either as function, or as
chainable methods. The latter can make your code shorter and easier to
read.

E.g., instead of:

    table.concat(
      table.sort(
        utils.table.map(
          utils.table.keys(words), string.lower
        )
      ),
      " "
    )

you can do:

    utils.table.new(words)
      :keys()
      :map(string.lower)
      :sort()
      :concat(" ")

@module utils.table
]]

---
-- Filters values.
--
-- Returns a new table with only the values that satisfied __predicate__.
-- The table __t__ is assumed to be a sequence.
--
-- @function filter
-- @args (t, predicate)
local function filter(t, predicate)
  local result = {}
  for _, v in ipairs(t) do
    if predicate(v) then
      result[#result + 1] = v
    end
  end
  return result
end

--[[

Our map() and imap() behave like Penlight's.

The glaring difference is that ours get the table as the first argument
(following the example of the functions in table.*).

This is different than Lua's Penlight, Python, Perl, PHP. Perhaps we
should switch our order to be compatible with them?

]]

---
-- Maps over a sequence.
--
-- Returns a new table with the results of applying __fn__ to the
-- elements `t[1], ..., t[#t]`.
--
-- @function imap
-- @args (t, fn)
local function imap(t, fn)
  local result = {}
  -- In my benchmarks, 'for i = 1, #t do ... t[i]' is faster
  -- than 'for i, v = ipairs(t)'. This also happens to be Penlight's
  -- implementation.
  for i = 1, #t do
    result[i] = fn(t[i]) or false
    -- The "or false" is a borrowing from Penlight. It makes sense.
  end
  return result
end

---
-- Maps over a table.
--
-- Returns a new table with the keys preserved and the values the result
-- of applying __fn__ to the original values.
--
-- [info]
--
-- Use @{imap} if your table is a sequence; that is, when the values
-- are keyed from `1` to `#t`.
--
-- Use @{map} if your table may contain arbitrary keys, not
-- necessarily numbers, which you want preserved.
--
-- [/info]
--
-- Note: For the sake of documenting your code, use @{imap} whenever it'd work
-- (even when @{map} too would have done the job). Use @{map} only when
-- the table isn't a sequence.
--
-- @function map
-- @args (t, fn)
local function map(t, fn)
  local result = {}
  for k, v in pairs(t) do
    -- Note: here we don't do "or false". It's an arbitrary decision IMHO. That's what
    -- Penlight does.
    result[k] = fn(v)
  end
  return result
end

-- The name "makeset" is borrowed from Penlight.

---
-- Converts a table to a _set_.
--
-- Returns a new table whose keys are the values of the original table.
-- The new values are all `true`.
--
-- @function makeset
-- @args (t)
local function makeset(t)
  local set = {}
  for _, v in ipairs(t) do
    set[v] = true
  end
  return set
end

---
-- Returns the keys of a table.
--
-- @function keys
-- @args (t)
local function keys(t)
  local ks = {}
  for k in pairs(t) do
    ks[#ks + 1] = k
  end
  return ks
end

---
-- Extracts a part of a table.
--
-- Behaves just like Lua's `string.sub` except that it operates on a
-- sequence. Negative indexes count from the end of the sequence.
--
-- @function sub
-- @args (t, first[, last])
local function sub(t, first, last)

  last = last or #t

  if first < 0 then
    first = #t + first + 1
  end
  if last < 0 then
    last = #t + last + 1
  end

  local result = {}
  for i = first, last do
    result[#result + 1] = t[i]
  end
  return result

end

---
-- Count the number of elements.
--
-- Useful for non-sequences only (use `#t` otherwise!).
--
-- @function count
-- @args (t)
local function count(t)
  local i = 0
  for _ in pairs(t) do i = i + 1 end
  return i
end

---
-- Iterates over a sequence values.
--
-- Note-short: This is simply an alternative to @{ipairs} in which the
-- keys aren't returned.
--
-- @function iterate
-- @args (t)
local function iterate(t)
  local i = 0
  return function()
    i = i + 1
    return t[i]
  end
end

------------------------------------------------------------------------------
--
-- Support for "chainable methods".
--

local new  -- forward declaration

local function wrap(fn)
  return function(...)
    local t = fn(...)
    return new(t)
  end
end

local function tap(fn)
  return function(t, ...)
    fn(t, ...)
    return t
  end
end

local mt = {  -- the metatable
  filter = wrap(filter),
  map = wrap(map),
  imap = wrap(imap),
  makeset = wrap(makeset),
  keys = wrap(keys),
  sub = wrap(sub),

  -- Non-wrappers (they aren't to return the table):
  iterate = iterate,
  count = count,

  -- Provide a few of Lua's builtins:
  sort = tap(table.sort),
  insert = tap(table.insert),
  remove = tap(table.remove),
  concat = table.concat,
}
mt.__index = mt

---
-- "Spices us" a table to support chainable methods.
--
-- For efficiency it does _not_ create a new table but operates in-place. The
-- table's metatable gets set.
--
-- [tip]
--
-- If you'll be using this function more than once, consider aliasing it to
-- prevent visual clutter:
--
--    local List = utils.table.new
--    -- The uppercase letter makes it look like a constructor.
--
-- [/tip]
--
-- @function new
-- @args ([t])
function new(t)
  return setmetatable(t or {}, mt)
end

------------------------------------------------------------------------------

return {
  filter = filter,
  map = map,
  imap = imap,
  makeset = makeset,
  keys = keys,
  sub = sub,
  count = count,
  iterate = iterate,

  new = new,
}
