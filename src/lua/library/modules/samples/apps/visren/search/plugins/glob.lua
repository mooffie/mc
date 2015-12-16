-- Searching using a glob pattern.

local M = {
  title = T"Shell wil&dcards",
}

local glob_compile, glob_to_replacement = import_from('utils.glob', {'compile', 'glob_to_replacement'})
local find = regex.find

M.does_match = function(s, r)
  return find(s, r)
end

M.find = function(s, r, idx)
  return find(s, r, idx)
end

M.compile_template = function(t)
  return glob_to_replacement(t)
end

M.compile_re = function(pat, is_case_sensitive, is_utf8)

  local f_utf8 = is_utf8 and "u" or ""
  local f_caseless = is_case_sensitive and "" or "i"

  local ok, r = pcall(function()
    return glob_compile(pat, f_utf8 .. f_caseless)
  end)
  if ok then
    return r
  else
    return nil, r:match("%d:%s*(.*)") or r  -- "r" is an error message.
  end

end

return M
