-- Searching using a regular expression.

local M = {
  title = T"&Perl-compatible regex"
}

local find = regex.find

M.does_match = function(s, r)
  return find(s, r)
end

M.find = function(s, r, idx)
  return find(s, r, idx)
end

M.compile_template = function(t)
  return t
end

-- The error message GLib's regexp returns is lengthy ("Error while compiling
-- regular expression %s at char %d: %s"). We try to shorten
-- it. (We might want to move this to the C side, but we won't get much:
-- while the C API tells us the errcode, it doesn't tell us the character
-- offset within the pattern.)
local function shorten_errmsg(msg)
   local pos, gist = msg:match "at char (%d+):%s*(.*)"
   if pos then
     return ("%s (at char %d)"):format(gist, tonumber(pos) + 1)
   else
     -- Failed. The msg might be localized. We at least cut off the file:line.
     return msg:match(":%d+:%s*(.*)") or msg
   end
end

M.compile_re = function(pat, is_case_sensitive, is_utf8)

  local f_utf8 = is_utf8 and "u" or ""
  local f_caseless = is_case_sensitive and "" or "i"

  local ok, r = pcall(function()
    return regex.compile { pat, f_utf8 .. f_caseless }
  end)
  if ok then
    return r
  else
    return nil, shorten_errmsg(r)  -- "r" is an error message.
  end

end

return M
