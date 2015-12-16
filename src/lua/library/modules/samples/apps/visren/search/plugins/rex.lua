--
-- Searching using a regular expression, with the Lrexlib library ( http://rrthomas.github.io/lrexlib/ )
--
-- This module was written when MC/Lua didn't have builtin regex support. Now
-- that this has changed, this module isn't used (it's commented out in ../init.lua).
--

local rex = require "rex_pcre"
local bor = require "utils.bit32".bor
local flags = rex.flags()

local M = {
  title = T"Perl-compatible rege&x (external lib)"
}

M.does_match = function(s, r)
  return r:find(s)
end

M.find = function(s, r, idx)
  return r:find(s, idx)
end

M.compile_template = function(t)
  return t
end

M.compile_re = function(pat, is_case_sensitive)

  local f_utf8 = assert(flags.UTF8)
  local f_caseless = is_case_sensitive and 0 or assert(flags.CASELESS)

  local ok, r = pcall(function()
    return rex.new(pat, bor(f_utf8, f_caseless))
  end)
  if ok then
    return r
  else
    return nil, r:match("%d:%s*(.*)") or r  -- "r" is an error message.
  end

end

return M
