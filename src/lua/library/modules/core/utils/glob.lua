--[[

This is a Lua version of MC's lib/search/glob.c .

We use Lua for easy experimentation. When the functions here differ a bit
from the C version (because of added features, fixes, etc) this is noted
by the comment "@dfc".

Eventually the things here may go back into the C version, and this one
go away. Or we'd keep using this one.

]]

------------------------------------------------------------------------------
-- Convert a glob pattern to a regex pattern.
--

local normal_tbl = {

  -- The C version allows '*' and '?' to match '/'. That "flexibility" was
  -- probably added to make the "Wildcard search" useful for the editor and
  -- such, but it's not really desirable for matching real pathnames. We
  -- have starstar instead. @dfc
  ['*'] = '([^/]*)',
  ['?'] = '([^/])',
  ['/'] = '/+', -- POSIX filesystems ignore excessive slashes. @dfc

  ['{'] = '(',
  ['}'] = ')',

  -- These need escaping:
  ['+'] = '\\+',
  ['.'] = '\\.',
  ['$'] = '\\$',
  ['('] = '\\(',
  [')'] = '\\)',
  ['^'] = '\\^',
  ['|'] = '\\|', -- @dfc

  -- starstar support. @dfc
  ['**']   = '.*',
  ['**/']  = '(?:.*/+)?',  -- "**/cake.c" souldn't match "yummycake.c", therefore we include "/" in the replacement too.
  ['/**']  = '/+.*',
  ['/**/'] = '/+(?:.*/+)?',
}

local inside_group_tbl = {
  ['{'] = '(?:',
  ['*'] = '[^/]*',
  ['?'] = '[^/]',
  [','] = '|',    -- comma is recognized only when inside a group. @dfc
}

-- A scanner for a glob pattern.
local tokenizer = regex.compile {
  [[
    (
      \\.
    |
      ( (^|/) \*\* (/|$) )
    |
      .
    )
  ]],
  "x"
}

local function glob_to_regex_string(s)
  local group_level = 0

  s = s:gsub('//+', '/') -- So, eventually, the pattern "one///two" turns into "one/+two". @dfc

  local re = regex.gsub(s, tokenizer, function(c, starstar)
    local translated = (group_level > 0 and inside_group_tbl[c]) or normal_tbl[c] or c
    if c == '{' then
      group_level = group_level + 1   -- @dfc
    end
    if c == '}' then
      group_level = group_level - 1
    end
    if starstar then
      translated = normal_tbl[starstar]
    end
    return translated
  end)

  return re
end

local function compile(gpat, flags)
  return regex.compile { '^' .. glob_to_regex_string(gpat) .. '$', flags }
end

------------------------------------------------------------------------------
-- Given a glob pattern, returns the corresponding regexp replacement
-- template.
--
--    assert(glob_to_replacement "file*.htm?" == "file\1.htm\2")
--    assert(glob_to_replacement "fi\\*le*.htm" == "fi*le\1.htm")
--
local function glob_to_replacement(s)
  local counter = 0
  -- @todo: Compare this with the C version. The C version is a bit different but not
  -- necessarily very correct.
  return regex.gsub(s, tokenizer, function(c)
    if c == '*' or c == '?' then
      counter = counter + 1
      return '\\' .. counter
    elseif c:len() > 1 and c:sub(1,1) == "\\" then
      -- Unescape the character.
      return c:sub(2)
    end
  end)
end

------------------------------------------------------------------------------

return {
  glob_to_regex_string = glob_to_regex_string,
  glob_to_replacement = glob_to_replacement,
  compile = compile,
}
