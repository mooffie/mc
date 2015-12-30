---
-- Filesystem access.
--
-- We augment here the C module with a few higher-level functions.
--
-- @module fs
--

local M = require('c.fs')

require('utils.magic')
  .setup_strict(M, true, false)  -- Guard against typos in constants' spelling.

--- Creates a temporary file.
--
-- Unless otherwise instructed, returns two values: a file object, and a pathname
--
-- The file is created with the permission 0600, meaning that only the owner will have access to its contents.
--
-- The optional **opts** may contain the following fields:
--
-- - name_only: Boolean. Return only the pathname; do not open the file.
-- - delete: Boolean. Delete the file immediacy; return only the file object.
-- - prefix: A string to appear at the beginning of the basename; defaults to "lua".
-- - suffix: A string to appear at the end  of the basename
--
-- @function temporary_file
-- @args ([opts])
function M.temporary_file(opts)
  opts = opts or {}
  local path = M._mkstemps(opts["prefix"], opts["suffix"])
  if opts["name_only"] then
    return path
  else
    local f = io.open(path, "r+")
    if opts["delete"] then
      M.unlink(path)
      return f
    else
      return f, path
    end
  end
end

return M
