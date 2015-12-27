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

---
-- Reads an entire file.
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
  local f, _a, _b = M.open(filename)
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
-- Writes an entire file.
--
-- This is a simple utility function that lets you create a file with
-- certain content in just one line of code:
--
-- Instead of the following proper code:
--
--    local f = assert(fs.open('file.txt', 'w'))
--    assert(f:write('output string'))
--    assert(f:close())
--
-- ...you can write:
--
--    assert(fs.write('file.txt', 'output string'))
--
-- **Returns:**
--
-- The function returns __true__ on sucess, or a triad on error.
--
-- Tip-short: You'd most certainly want to wrap the function call in
-- @{assert}, to raise an exception on error.
--
-- @function write
-- @args (filename, ...)
M.write = function(filename, ...)
  local f, _a, _b = M.open(filename, 'w')
  if not f then
    return nil, _a, _b
  end
  local ok, _a, _b = f:write(...)
  if not ok then
    return nil, _a, _b
  end
  return f:close()
end

---
-- Iterates over a file's lines.
--
-- This is like Lua's built-in @{io.lines}, but it supports the *Virtual File System*.
--
-- @function lines
-- @args (filename[, what])
function M.lines(filename, ...)

  -- Since io.lines() is faster (no VFS layer), we delegate
  -- to it when possible.
  if not filename or fs.VPath(filename):is_local() then
    return io.lines(filename, ...)
  end

  local f = assert(M.open(filename))
  local what = select(1, ...)

  return function()
    local res = f:read(what)
    if not res then
      f:close()
    end
    return res
  end

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
-- [concurs with the C standard](https://www.securecoding.cert.org/confluence/display/c/FIO39-C.+Do+not+alternately+input+and+output+from+a+stream+without+an+intervening+flush+or+positioning+call)
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

---
-- Creates a temporary file.
--
-- Unless otherwise instructed, returns two values: a @{fs.File|file object}, and a pathname
--
-- The file is created with the permission 0600, meaning that only the owner will have access to its contents.
--
-- If the file could not be created (e.g., on a read-only filesystem), raises an exception.
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
    local f = assert(M.open(path, "r+"))  -- Although _mkstemps() would have raised an exception already.
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

M.autoload('glob', {'fs.glob', 'glob'})
 .autoload('tglob', {'fs.glob', 'tglob'})
 .autoload('fnmatch', {'fs.glob', 'fnmatch'})

return M
