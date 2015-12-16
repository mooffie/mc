---
-- @module luafs

--- Returns a file.
--
-- Implementing the `file()` operator is an easy alternative to implementing
-- @{open}/@{read}/@{write}/@{seek}/@{close}.
--
-- The file() operator gets exactly the same arguments @{open} gets. The
-- difference is that 'file' may not return any arbitrary object but either of:
--
-- - A string, which stands for the whole contents of the file. In this
--   case the file can only be opened for reading. If it's opened for writing,
--   a "Read-only file system" error will be generated.
--
-- - A file object (e.g., the result of @{fs.open}, @{io.open} or
--   @{io.popen} (though the latter may cause trouble for tasks that wish to
--   seek in the file, like MC's editor)).
--
-- (or, it may return a triad, or nothing; same as @{open}.)
--
--    function MyFS:file(pathname)
--      if pathname == "a.txt" then
--        return "contents of a.txt"
--      end
--    end
--
-- @attr file
-- @args (session, pathname, mode, info)


local do_stat = require('luafs')._do_stat
local errors = require('fs')

------------------------------- StringIO class -------------------------------

-- The StringIO class is somewhat like Python/Ruby's StringIO. It supports only reading.

local StringIO = {}
StringIO.__index = StringIO

function StringIO.new(s)
  return setmetatable({
    s = s,
    pos = 1,
  }, StringIO)
end

function StringIO:read(count)
  local s = self.s:sub(self.pos, self.pos + count - 1)
  self.pos = self.pos + count
  return s
end

function StringIO:write(buf)
  -- "String" files don't support writing to.
  -- According to write(2) man page, EBADF is to be returned, but EROFS ("Read-only file system") is clearer.
  return nil, errors.EROFS
end

function StringIO:seek(whence, offs)
  -- Note: 'offs' is zero-based, so we "+ 1" to convert to Lua.
  if whence == "cur" then
    self.pos = self.pos + offs
  elseif whence == "end" then
    self.pos = self.s:len() + offs + 1
  else
    self.pos = offs + 1
  end
  return true
end

function StringIO:close()
  return true
end

------------------------------------------------------------------------------

local function is_file(obj)
  return (type(obj) == "table" or type(obj) == "userdata") and obj.read and obj.write and obj.seek and obj.close
end

local implementation = {

  open = function(session, path, mode, info)

      local contents, a, b = session.fs.file(session, path, mode, info)

      if not contents then
        return nil, a, b
      end

      if type(contents) == "string" then
        if mode ~= "r" then
          -- "String" files don't support writing to.
          return nil, errors.EROFS -- "Read-only file system"
        end
        return {
          f = StringIO.new(contents),
          -- We store the path for later, for our fstat().
          path = path,
        }
      elseif is_file(contents) then
        return {
          f = contents,
          path = path,
        }
      else
        error(E"The '%s' filesystem's file() operation must return either a string or a file object; but %s was returned.":format(
          session.fs.prefix, type(contents)))
      end

  end,

  -- 'pkg' henceforth is what open() returned.

  fstat = function(session, pkg)
    if pkg.f.stat then
      return pkg.f:stat()
    else
      -- Fall back to stat()
      return do_stat(session, session.fs.stat, pkg.path)
    end
  end,

  -- We give preference to sysread/syswrite.

  read = function(_, pkg, count)
    local f = pkg.f
    return (f.sysread or f.read)(f, count)
  end,

  write = function(_, pkg, buf)
    local f = pkg.f
    return (f.syswrite or f.write)(f, buf)
  end,

  seek = function(_, pkg, whence, offs)
    return pkg.f:seek(whence, offs)
  end,

  close = function(_, pkg)
    return pkg.f:close()
  end,

}

local function install(fs)
  if fs.file then

    if fs.open or fs.read or fs.write or fs.seek or fs.fstat or fs.close then
      error(E"A filesystem that implements file() must not implement any of: open/read/write/seek/fstat/close().")
    end

    for name, func in pairs(implementation) do
      if not fs[name] then
        fs[name] = func
      end
    end

  end
end

return {
  install = install,
}

--[[

@todo?

MC sometimes open()s a file more than once:

    - F3 = file opened twice (getlocalcopy(), viewer)
    - Shift-F3 = file opened once.
    - F4 = file opened trice!

For some filesystems open() is costly (e.g., if it requires
extracting file from archive). We could alleviate the problem
by caching their files for them:

  - Their file() would return, say, a VPath (e.g. pointing to a temporary file).
  - We'll keep returning fs.open(vpath) as long as no write operations
    are performed on that filesystem.
  - We'll delete the files pointed at (by these VPaths) when the session
    gets closed.

--]]
