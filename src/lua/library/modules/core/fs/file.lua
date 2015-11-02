--[[-

The `File` class represents an open file returned by @{fs.open}.

As a rule of thumb, you should open files with @{fs.open} instead of
@{io.open} because the latter doesn’t support the _Virtual File System_.

Info: This class is a superset of Lua's own file object and you use it
in the same way. Therefore many of the entries here link to Lua's
manual.

@classmod fs.File

]]


--[[

Programmers:

Places marked with "@optimization" are *space* optimization: it
prevents Lua from allocating big strings.

While "premature optimization is the root of all evil", this isn't the
case here. Buffers may be huge and it's better to be conscience about
them from the start than rewrite the whole thing later.

]]

---------------------------------- Imports -----------------------------------

local posix = require "fs.filedes"
local const = require "fs"

local create_input_buffer = require('fs.inputbuffer')
local create_output_buffer = require('fs.outputbuffer')

local bor = require("utils.bit32").bor
local enable_table_gc = require("utils.magic").enable_table_gc

----------------------------------- Utils ------------------------------------

local function DBG(...)
  --print(...)
end

-- @optimization
--
-- Concats two strings.
--
-- Lua 5.2 does this optimization internally, but for Lua 5.1 and luaJIT we do
-- this explicitly. See:
--
--   http://stackoverflow.com/questions/22781134/does-lua-optimize-concatenating-with-an-empty-string
--
local function concat(a, b)
  return (a == "" and b) or (a .. b)
end

------------------------------------------------------------------------------

local modes = {
  r      = const.O_RDONLY,
  w      = bor(const.O_WRONLY, const.O_CREAT, const.O_TRUNC),
  a      = bor(const.O_WRONLY, const.O_CREAT, const.O_APPEND),
  ["r+"] = const.O_RDWR,
  ["w+"] = bor(const.O_RDWR,   const.O_CREAT, const.O_TRUNC),
  ["a+"] = bor(const.O_RDWR,   const.O_CREAT, const.O_APPEND),
}

local whences = {
  set     = const.SEEK_SET,
  cur     = const.SEEK_CUR,
  ["end"] = const.SEEK_END,
}

local File = {}
File.__index = File

------------------------------------------------------------------------------

---
-- Sets the buffering mode for an output file.
--
-- See Lua's @{file:setvbuf}
--
-- @args (mode[, size])
function File:setvbuf(mode, size)
  self.obuffer:setvbuf(mode, size)
end

---
-- Writes to file.
--
-- See Lua's @{file:write}
--
-- (Because of @{setvbuf|buffering} you may have to call @{flush} to actually see the data written out.)
--
function File:write(...)
  local t = { ... }
  local s = (#t == 1) and t[1] or table.concat(t)    -- @optimization
  if not self.obuffer:add(s) then
    return self.obuffer:return_error()
  end
  return self
end

-- Answers "are we at EOF?"
function File:is_eof()
  if self.ibuffer:is_empty() then
    self.ibuffer:read_more()
    return self.ibuffer:is_empty()
  else
    return false
  end
end

function File:read_block(size)
  -- Lua's documentation for io.File:read() effectively says that size==0 is
  -- a special case: it answers whether we're at EOF. One *has* to read some
  -- data to know the answer. Lua's C source does this by doing getc/ungetc,
  -- and we effectively mimic this in our File:is_eof().
  --
  -- (See http://www.lua.org/source/5.2/liolib.c.html#g_read and test_eof() there.)
  if size == 0 then
    if self:is_eof() then
      return nil
    else
      return ""
    end
  end

  local head = self.ibuffer:get_by_size(size)
  local remaining = size - head:len()

  if remaining == 0 then
    -- The whole block data was already available in the buffer. Return it.

    return head

  else
    -- Not all the block was available in the buffer. We read more.

    local tail

    DBG("getting next chunk")
    if not self.ibuffer:read_more(remaining)  then
      return self.ibuffer:return_error()
    end

    tail = self.ibuffer:get_by_size(remaining)

    local all = concat(head, tail)
    if all == "" then
      -- This can only be EOF.
      return nil
    else
      return all
    end
  end
end

-- This is a temporary implementation for reading the whole file.
--
-- Alternatives:
--
--  * We could load the whole file in one slurp (using fstat() or seek("end")
--    to find its size), but the memory peak would be 2 times the file size
--    because two strings are used: temporarily on the C side
--    (see fs-filedes.c:l_read), and on the Lua side.
--
--  * We could write this in C and use Lua's luaL_Buffer structure to solve
--    the 2x problem(?)
--
--  * LuaTex has readall():
--
--      http://mirror.hmc.edu/ctan/macros/luatex/generic/lualibs/lualibs-io.lua
--
--    They say "The next one is upto 50% faster on large files and less memory
--    consumption due to less intermediate large allocations." Maybe we should
--    copy their code. I've deliberately not looked into their code because of
--    copyright concerns.
--
--  * google 'file_slurp.lua'
--
--  * Lua's own implementation is here:
--
--      http://www.lua.org/source/5.2/liolib.c.html#read_all
--
function File:read_all()

  -- Lua's documentation for file:read's "*a" say we aren't to return nil on EOF.

  local t = {}

  t[1] = self.ibuffer:get()

  while true do

    if not self.ibuffer:read_more() then
      return self.ibuffer:return_error()
    end

    local b = self.ibuffer:get()

    t[#t + 1] = b

    if b == "" then
      break
    end

  end

  return table.concat(t)

end

function File:read_line(keep_eol)

  while true do

    local pos_lf = self.ibuffer:find("\n")

    if pos_lf then
      return self.ibuffer:get(pos_lf, keep_eol and 0 or 1)
    end

    -- Continue reading chunks till we see a newline.

    if not self.ibuffer:read_more() then
      return self.ibuffer:return_error()
    end

    if self.ibuffer.eof then
      local line = self.ibuffer:get()
      if line == "" then
        -- We're required to return nil on EOF.
        return nil
      else
        return line
      end
    end

  end

end

---
-- Reads from file.
--
-- See Lua's @{file:read}
--
-- The only difference is that the "*n" format isn't supported.
--
-- @args ([what])
function File:read(what)
  if not what or what == "*l" or what == "*line" then
    return self:read_line(false)
  elseif what == "*L" then
    return self:read_line(true)
  elseif what == "*a" or what == "*all" then
    return self:read_all()
  elseif type(what) == "number" then
    return self:read_block(what)
  else
    error(E"Invalid argument to read(). Possible values: *a, *l, *L, number.")
  end
end

---
-- Returns an iterator over the file's contents.
--
-- See Lua's @{file:lines}
--
-- @args ([what])
function File:lines(what)
  return function()
    return self:read(what)
  end
end

---
-- Reads from file, non-buffered.
--
-- This function reads from the file directly instead of using a buffer
-- like @{read} does.
--
-- In other words, this function is like Unix's @{read(2)} whereas @{read}
-- is like Unix's @{fread(3)}.
--
-- **Return value:** see that of @{fs.filedes.read}.
--
-- Info-short: The name comes from the Perl (and Ruby) function by the same name.
--
-- Note-short: Caveat: Don't mix buffered I/O with unbuffered I/O.
--
function File:sysread(count)
  return posix.read(self.fd, count)
end

---
-- Stats the file.
--
-- Similar to @{fs.stat}.
--
--    local f = assert(fs.open("/etc/fstab"))
--    local s = f:stat()
--
--    print(s.blksize)   -- 4096 (for example)
--
-- @args ([...])
function File:stat(...)
  return posix.fstat(self.fd, ...)
end

---
-- Writes to file, non-buffered.
--
-- This function writes to the file directly instead of using a buffer
-- like @{write} does.
--
-- In other words, this function is like Unix's @{write(2)} whereas @{write}
-- is like Unix's @{fwrite(3)}.
--
-- **Return value:** see that of @{fs.filedes.write}.
--
-- Info-short: The name comes from the Perl (and Ruby) function by the same name.
--
-- Note-short: Caveat: Don't mix buffered I/O with unbuffered I/O.
--
function File:syswrite(s)
  return posix.write(self.fd, s)
end

---
-- Seeks in file.
--
-- See Lua's @{file:seek}
--
-- @args ([whence[, offset]])
function File:seek(whence, offset)
  whence = whence or "cur"
  offset = offset or 0

  local iwhence = whences[whence] or error(E"Invalid seek whence '%s'.":format(tostring(whence)))

  if not self.obuffer:flush() then
    return self.obuffer:return_error()
  end

  if whence == "cur" then
    offset = offset - self.ibuffer:calculate_offset()
  end

  self.ibuffer:clear()

  return posix.lseek(self.fd, offset, iwhence)
end

---
-- Saves any written data to the file.
--
-- See Lua's @{file:flush}
function File:flush()
  if not self.obuffer:flush() then
    return self.obuffer:return_error()
  else
    return true
  end
end

---
-- Closes the file.
--
-- See Lua's @{file:close}
function File:close()
  local flush_result = { self:flush() }
  local close_result = { posix.close(self.fd) }

  -- Functions on the C side dealing with file descriptors cause MC to
  -- segfault when given an invalid fd. We set it to a special sentry value
  -- to prevent this in case the user continues to work with the file. We
  -- could have used 'nil' too, but the error message would not be as clear.
  --
  -- See vfs_bug_crash.lua in the 'test' folder.
  self.fd = posix.CLOSED_FD
  self.ibuffer.fd = posix.CLOSED_FD
  self.obuffer.fd = posix.CLOSED_FD

  if not flush_result[1] then
    return table.unpackn(flush_result)
  else
    return table.unpackn(close_result)
  end
end

function File:__gc()
  if self.fd ~= posix.CLOSED_FD then  -- (don't close a closed file.)
    self:close()
  end
end

-- Converts a symbolic mode, like "rw", to its POSIX numeric value, unless it's already a number.
local function parse_mode(mode)
  if type(mode) == "number" then
    return mode
  elseif type(mode) == "string" then
    local _mode = mode:gsub("b", "") -- All files are "binary" to us; we don't support explicit "b" (which is fine, as we're expected to run on POSIX systems).
    if modes[_mode] then
      return modes[_mode]
    else
      error(E"Invalid open mode '%s'.":format(tostring(mode)))
    end
  else
    error(E"Invalid open mode (string or number expected).")
  end
end

------------------------------------------------------------------------------

function File.new(filepath, mode, perm)
  local imode = parse_mode(mode or "r")

  local fd, reason, errcode = posix.open(filepath, imode, perm)
  if not fd then
    return nil, reason, errcode
  end

  -- fstat() may fail in a buggy LuaFS filesystem: if the filesystem lets
  -- you open() files whose stat/lstat() returns nil. Therefore we wrap it in assert().
  local blksize = math.max(assert(posix.fstat(fd, "blksize")), 512)

  local self = {
    fd = fd,
    ibuffer = create_input_buffer(fd, blksize),
    obuffer = create_output_buffer(fd, blksize),
  }

  return enable_table_gc(setmetatable(self, File))
end

------------------------------------------------------------------------------

local M = {
  open = File.new,
}

return M
