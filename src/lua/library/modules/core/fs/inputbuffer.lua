--[[

Programmers:

  See file.lua for explanation about "@optimization".

]]


local posix = require "fs.filedes"

local function DBG(...)
  --print(...)
end

local InputBuffer = {}
InputBuffer.__index = InputBuffer

function InputBuffer.New(fd, blksize)
  local self = {
    buffer = "",
    fd = fd,
    start = 1,
    error = nil,
    eof = false,
    BUFSIZ = blksize or 4096,
  }
  return setmetatable(self, InputBuffer)
end

local function concat(a, b)    -- Copied from file.lua. See rationale there.
  return (a == "" and b) or (a .. b)
end

function InputBuffer:is_empty()
  return self.buffer == ""
end

-- Appends to the buffer. Its main byproduct is to cut out the start of the buffer (which we've already served).
function InputBuffer:append(s)
  if s ~= "" then
    local head = (self.start == 1) and self.buffer or self.buffer:sub(self.start)   -- @optimization
    self.buffer = concat(head, s)
    self.start = 1
  end
end

-- Reads the next chunk (at least 'size' bytes) from disk into the buffer.
-- Returns 'false' on error.
--
-- At a minimum it reads BUFSIZ bytes. That's the idea of buffered I/O.
--
function InputBuffer:read_more(count)
  DBG("read from disk")
  local s, errmsg, errcode = posix.read(self.fd, math.max(count or 0, self.BUFSIZ))
  if s then
    if s ~= "" then
      self:append(s)
      self.eof = false
    else
      self.eof = true
    end
    return true
  else
    self.error = { nil, errmsg, errcode }
    return false
  end
end

function InputBuffer:return_error()
  return table.unpackn(self.error)
end

function InputBuffer:find(needle)
  return self.buffer:find(needle, self.start)
end

function InputBuffer:clear()
  self.buffer = ""
  self.start = 1
  -- Note: we don't need to reset 'eof' and 'error': they're inspected after calling read_more() only.
end

-- Get the rest of the bytes that are already in the buffer, till position 'till'. Doesn't read from disk.
--
-- 'minus' is often '-1' to mean that the returned string is to be missing its last byte (a newline).
--
-- @usage bf:get_by_size(12)
-- @usage bf:get(bf:find('\n'))
--
function InputBuffer:get(till, minus)
  local buf_len = self.buffer:len()
  till = till or buf_len
  local s
  do
    -- @optimization
    local start = self.start
    local finish = till - (minus or 0)
    if start == 1 and finish >= buf_len then
      s = self.buffer
    else
      s = self.buffer:sub(start, finish)
    end
  end
  if till >= buf_len then
    DBG("clearing")
    -- We've served all the buffer, so we can delete it to save memory.
    self.buffer = ""
    self.start = 1
  else
    self.start = till + 1
  end
  return s
end

function InputBuffer:calculate_offset()
  return self.buffer:len() + 1 - self.start
end

-- Get up to 'size' bytes. Only looks at what's already in the buffer; doesn't try to read more from disk.
function InputBuffer:get_by_size(size)
  local till = self.start + size - 1      -- this may exceed self.buffer:len(), but that's ok.
  return self:get(till)
end

return InputBuffer.New
