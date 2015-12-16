-- Exposes an Editbox.

local append = table.insert

local WorldMeta = {}
WorldMeta.__index = WorldMeta

local function new(...)
  local self = setmetatable({}, WorldMeta)
  self:init(...)
  return self
end

-- Converts byte offset to line number.
local function offs_to_line(edt, offs)
  edt.cursor_offs = offs
  return edt.cursor_line
end

function WorldMeta:init(edt)
  self.edt = edt

  local start, stop = edt:get_markers()
  if start then
    self.line_to = offs_to_line(edt, stop)
    self.line_from = offs_to_line(edt, start)
  else
    self.line_to = edt.max_line
    self.line_from = 1
  end
end

function WorldMeta:is_utf8()
  return self.edt:is_utf8()
end

function WorldMeta:get_items()
  local items = {}
  local edt = self.edt

  for i = self.line_from, self.line_to do
    append(items, edt:get_line(i))
  end

  return items
end

function WorldMeta:rename(replacements)

  local map = {}

  for _, r in ipairs(replacements) do
    map[r.source] = r.target
  end

  local edt = self.edt

  edt:command "home" -- Move to 1st column (edt.cusor_col is read-only).

  for i = self.line_from, self.line_to do
    local ln = edt:get_line(i)
    if map[ln] then
      edt.cursor_line = i
      edt:delete(ln:len())
      edt:insert(map[ln])
    end
  end

end

return {
  new = new,
}
