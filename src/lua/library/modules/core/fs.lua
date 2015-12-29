---
-- Filesystem access.
--
-- We augment here the C module with a few higher-level functions.
--
-- @module fs
--

local M = require('c.fs')

M.dir, M.files, M.opendir = import_from('fs.dir', {'dir', 'files', 'opendir'})

require('utils.magic')
  .setup_strict(M, true, false)  -- Guard against typos in constants' spelling.

---
-- Creates a temporary file.
--
-- Unless otherwise instructed, returns two values: a file object, and a pathname
--
-- The file is created with the permission 0600, meaning that only the owner will have access to its contents.
--
-- If the file could not be created (e.g., on a read-only filesystem), raises an exception.
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
    local f = assert(io.open(path, "r+"))  -- Although _mkstemps() would have raised an exception already.
    if opts["delete"] then
      M.unlink(path)
      return f
    else
      return f, path
    end
  end
end

---
-- Creates a temporary file with certain content.
--
-- Writes a string (or strings) to a temporary file and returns the path
-- to this file.
--
-- Tip-short: This is simply an easy-to-use wrapper around @{temporary_file}.
--
-- In case of error, raises an exception.
--
-- Example:
--
--    local temp = fs.temporary_string_file(
--      "[client]\n",
--      "user=" .. user .. "\n",
--      "password=" .. password .. "\n"
--    )
--    os.execute("mysqldump --defaults-extra-file=" .. temp .. " mydb tbl1")
--    assert(fs.unlink(temp))
--
-- [tip]
--
-- This:
--
--    fs.temporary_string_file(huge_string, "\n")
--
-- ... is more efficient than this:
--
--    fs.temporary_string_file(huge_string .. "\n")
--
-- (This tip applies to @{file:write} too.)
--
-- [/tip]
--
-- @function temporary_string_file
-- @args (...)
function M.temporary_string_file(...)
  local path = M.temporary_file{name_only=true}
  local f = assert(io.open(path, 'w'))
  assert(f:write(...))
  assert(f:close())
  return path
end

return M
