--[[

Pretty printer.

Let's keep this file PUBLIC DOMAIN so anybody can use it for their projects.

The output is modeled after Enrique García Cota's inspect.lua with some
improvements.

Example:

    pp { 11, 12, 13, 14, a="a", b="b", c="c" }

Gives:

    {
      11, 12, 13, 14,
      a = "a",
      b = "b",
      c = "c"
    }

The general rule:

The array part is printed all elements on one line, and the associative part one
element per line.

Improvements:

- If the elements of the array part are, on average, long, they're
  instead printed each element per line (this makes matrices and arrays
  of strings easier to read).

- If an associative table contains a single simple element, everything
  is printed on one line.

CIRCULAR/DUPLICATE REFERENCE NOTATION
-------------------------------------

Example:

    local t = { 3.1, 3.2, 3.3 }
    t.self = t
    local r = {}
    pp { t, t, t, r, r }

Gives:

    {
      <1>{
        3.1, 3.2, 3.3,
        self = <table 1>
      },
      <table 1>,
      <table 1>,
      <2>{},
      <table 2>
    }

]]

local append = table.insert

local with_meta = true  -- whether to print metatables.

local stats = {}

local function init_stats()

  stats = {

    seen = {},

    table = {
      duplicates = {},
      duplicates_count = 0,
    },

    funcs = {
      seen_count = 0,
    }
  }

end

local pp

--
-- Pretty prints a function.
--
local function pp_function(f)
  if not stats.seen[f] then
    stats.funcs.seen_count = stats.funcs.seen_count + 1
    stats.seen[f] = stats.funcs.seen_count
  end
  return "<function " .. stats.seen[f] .. ">"
end

--
-- Pretty prints a string.
--
local function pp_string(s)
  return ("%q"):format(s):gsub("\\\n", "\\n")
end

-- Concatenates arrays.
local function imerge(base, ext, ...)
  if ext then
    for _, v in ipairs(ext) do
      base[#base + 1] = v
    end
    return imerge(base, ...)
  else
    return base
  end
end

--
-- Returns all the keys of an associative table.
-- Sorts by numbers, then strings, then everything else.
--
local function get_assoc_keys(t)
  local array_max = #t
  local assoc_keys__numeric = {}
  local assoc_keys__string = {}
  local assoc_keys__others = {}
  for k, _ in pairs(t) do
    if type(k) == "string" then
      append(assoc_keys__string, k)
    elseif type(k) == "number" then
      if k < 1 or k > array_max then
        append(assoc_keys__numeric, k)
      end
    else
      append(assoc_keys__others, k)
    end
  end
  table.sort(assoc_keys__numeric)
  table.sort(assoc_keys__string)
  return imerge({}, assoc_keys__numeric,
                    assoc_keys__string,
                    assoc_keys__others)
end

local keywords_s = [[
     and       break     do        else      elseif    end
     false     for       function  goto      if        in
     local     nil       not       or        repeat    return
     then      true      until     while
]]
local keywords = {}

for kw in keywords_s:gmatch("%S+") do
  keywords[kw] = true
end

local function render_key(k, level)
  if type(k) == "string" and k:match("^[%a_][%a%d_]*$") and not keywords[k] then
    return k
  else
    return "[" .. pp(k, level + 1) .. "]"
  end
end

local function table_num(t)
  if type(stats.table.duplicates[t]) ~= "number" then --- it's boolean initially.
    stats.table.duplicates_count = stats.table.duplicates_count + 1
    stats.table.duplicates[t]    = stats.table.duplicates_count
  end
  return stats.table.duplicates[t]
end

local function indent(text)
  return "  " .. text:gsub("\n", "\n  ")
end
local indent_str = indent("")

-- Opines as to whether the elements seem too complex to be printed
-- horizontally (they will instead be printed vertically).
local function is_complex(elts)
  local all = table.concat(elts)

  if all:find "\n" then
    -- If the horizontals contain a table, they should be vertical.
    return true
  elseif #elts > 2 and (all:len() / #elts) > 10 then
    -- If each element is relatively long.
    return true
  else
    return false
  end
end

--
-- Pretty prints a table.
--
local function pp_table(t, level)

  if stats.seen[t] then
    return "<table " .. table_num(t) .. ">"
  end

  stats.seen[t] = true

  local prefix = ""
  if stats.table.duplicates[t] then
    prefix = "<" .. table_num(t) .. ">"
  end

  --
  -- Render the array part, by default horizontally.
  --

  local horizontals = {}
  for i = 1, #t do
    append(horizontals, pp(t[i], level + 1))
  end

  --
  -- Render the assoc part, by default vertically.
  --

  local verticals = {}
  for _, k in ipairs(get_assoc_keys(t)) do
    append(verticals, render_key(k, level+1) .. " = " .. pp(t[k], level+1))
  end
  if with_meta and getmetatable(t) then
    append(verticals, "<metatable> = " .. pp(getmetatable(t), level+1))
  end

  --
  -- Tweak the default layout.
  --

  -- If the assoc part contains just one element, we want to print it
  -- "{ k = 6 }", not "{\n  k = 6\n}".
  if #verticals == 1 and #horizontals <= 1 then
    append(horizontals, verticals[1])
    verticals = {}
  end

  -- If the array part seems complex, print it vertically.
  if is_complex(horizontals) then
    verticals = imerge(horizontals, verticals)
    horizontals = {}
  end

  --
  -- Join the elements.
  --

  if #horizontals ~= 0 then
    horizontals = table.concat(horizontals, ", ")
  else
    horizontals = nil
  end

  if #verticals ~= 0 then
    verticals = indent( table.concat(verticals, ",\n") )
  else
    verticals = nil
  end

  --
  -- Master join.
  --

  local result

  if horizontals then
    if verticals then
      result = prefix .. "{\n" .. indent_str .. horizontals .. ",\n" .. verticals .. "\n}"
    else
      result = prefix .. "{ " .. horizontals .. " }"
    end
  elseif verticals then
    result = prefix .. "{\n" .. verticals .. "\n}"
  else
    result = prefix .. "{}"
  end

  return result
end

local function find_duplicate_tables(t)

  if stats.seen[t] then
    -- We've seen this object before. Now it's the second time: mark it as duplicate.
    stats.table.duplicates[t] = true
    return
  end

  stats.seen[t] = true

  for k, v in pairs(t) do
    if type(k) == "table" then
      find_duplicate_tables(k)
    end
    if type(v) == "table" then
      find_duplicate_tables(v)
    end
  end

  if with_meta and getmetatable(t) then
    find_duplicate_tables(getmetatable(t))
  end

end

--
-- Pretty prints a value.
--
-- This is the main function.
--
pp = function(o, level)
  level = level or 0

  if level == 0 then
    init_stats()
  end

  local pretty

  if type(o) == "table" then
    if level == 0 then
      find_duplicate_tables(o)
      stats.seen = {}    -- prepare for 2nd pass.
    end
    pretty = pp_table(o, level)
  elseif type(o) == "function" then
    pretty = pp_function(o)
  elseif type(o) == "string" then
    pretty = pp_string(o)
  else
    -- anything else.
    pretty = tostring(o)
  end

  if level == 0 then
    init_stats()  -- clear memory.
  end

  return pretty
end

return {
  pp = pp,
}
