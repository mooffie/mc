
local posix = require "fs.filedes"

local function DBG(...)
  --print(...)
end

local OutputBuffer = {}
OutputBuffer.__index = OutputBuffer

local append = table.insert

function OutputBuffer.New(fd, blksize)
  local self = {
    pending = {},
    pending_size = 0,
    fd = fd,
    error = nil,
    mode = "full",
    BUFSIZ = blksize or 4096,
  }
  return setmetatable(self, OutputBuffer)
end

function OutputBuffer:return_error()
  return table.unpackn(self.error)
end

function OutputBuffer:setvbuf(mode, size)
  assert( ({no = true, full = true, line = true})[mode], E"invalid buffer mode '%s'":format(tostring(mode)))
  assert(type(size or 0) == "number", E"invalid size")
  self.mode = mode
  self.BUFSIZ = size or self.BUFSIZ
end

function OutputBuffer:flush()
  if self.pending_size ~= 0 then
    DBG("actually flushing...")
    local all = table.concat(self.pending)
    local success, errmsg, errcode = posix.write(self.fd, all)

    self.pending = {}
    self.pending_size = 0

    if not success then
      self.error = { nil, errmsg, errcode }
      return false
    end
  end
  return true
end

function OutputBuffer:_add(s)
  append(self.pending, s)
  self.pending_size = self.pending_size + s:len()
  if self.pending_size >= self.BUFSIZ or self.mode == "no" then
    return self:flush()
  end
  return true
end

function OutputBuffer:add(s)
  assert(type(s) == "string")
  if self.mode == "line" then
    local pos_lf = s:find("\n")   -- I wish there was an rfind().  http://stackoverflow.com/questions/17386792/how-to-implement-string-rfind-in-lua
    if pos_lf then
      local head, tail = s:sub(1, pos_lf), s:sub(pos_lf + 1)
      return self:_add(head) and self:flush() and self:add(tail)
    end
  end
  return self:_add(s)
end

return OutputBuffer.New
