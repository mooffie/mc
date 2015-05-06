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
  .setup_autoload(M)
  .setup_strict(M, true, false)  -- Guard against typos in constants' spelling.

--- Reads an entire file.
--
-- This is a simple utility function.
--
-- The optional **length** argument lets you read only a portion of the
-- file. This argument is passed down to @{fs.File:read} and defaults to
-- `"*a"`.
--
-- The optional **offset** argument lets you seek in the file before reading.
-- A negative offset means seeking from the end of the file.
--
-- **Returns:**
--
-- The function returns the string read, or a triad on error.
--
-- Tip-short: Wrap the function call in @{assert} if you want to raise an exception
-- on error.
--
-- @function read
-- @args (filename[, length[, offset]])
M.read = function(filename, what, offset)
  local f, _a, _b = fs.open(filename)
  if not f then
    return nil, _a, _b
  end
  if offset then
    local i, _a, _b = f:seek(offset < 0 and "end" or "set", offset)
    if not i then
      return nil, _a, _b
    end
  end
  local s, _a, _b = f:read(what or "*a")
  f:close()

  --
  -- A special case: When doing fs.read(filename) on an empty file
  -- f:read() returns an empty string. When doing fs.read(filename, 1024),
  -- however, f:read() returns nil. That's f:read()'s behavior. To make
  -- life easier to the user we convert this nil to an empty string.
  --
  if not s and not _a and type(what) == "number" then
    s = ""
  end

  return s, _a, _b
end

---
-- Opens a file.
--
-- Returns a @{fs.File} object on success, or a triad on error.
--
-- You should use this function instead of @{io.open} because the latter doesn't
-- support the *Virtual File System*. Some extensions this function introduces:
--
-- **mode** is either a symbolic symbolic mode name (like "r", "w+", etc.) or a
-- numeric code (like `utils.bit32.bor(fs.O_RDWR, fs.O_APPEND)`).
--
-- **perm** is the permission with which to create new files. Defaults to 0666
-- (which will be further clipped by the umask).
--
-- [note]
--
-- When opening a file for both input and output, you must intervene
-- between :read() and :write() operations by :seek() or :flush(). This
-- [concurs with the C standard](https://www.securecoding.cert.org/confluence/display/seccode/FIO39-C.+Do+not+alternately+input+and+output+from+a+stream+without+an+intervening+flush+or+positioning+call)
-- as well.
--
-- (This issue pertains to buffered IO only. When doing unbuffered IO
-- (using :sysread() and :syswrite()) this issue doesn't exist.)
--
-- [/note]
--
-- @function open
-- @args (filepath, [mode], [perm])
M.autoload('open', {'fs.file', 'open'})

--- Creates a temporary file.
--
-- Unless otherwise instructed, returns two values: a @{fs.File|file object}, and a pathname
--
-- The file is created with the permission 0600, meaning that only the owner will have access to its contents.
--
-- The optional **opts** may contain the following fields:
--
-- - name_only: Boolean. Return only the pathname; do not open the file.
-- - delete: Boolean. Delete the file immediacy; return only the @{fs.File|file object}.
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
    local f = M.open(path, "r+")
    if opts["delete"] then
      M.unlink(path)
      return f
    else
      return f, path
    end
  end
end

--- Registers a filesystem.
--
-- See the @{~filesystem|user guide} for a detailed explanation.
--
-- @function register_filesystem
-- @args (spec)

M.autoload('glob', {'fs.glob', 'glob'})
 .autoload('tglob', {'fs.glob', 'tglob'})
 .autoload('fnmatch', {'fs.glob', 'fnmatch'})
 .autoload('register_filesystem', {'luafs', 'register_filesystem'})

return M
