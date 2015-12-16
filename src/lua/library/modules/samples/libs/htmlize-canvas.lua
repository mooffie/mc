--[[

Augments the Canvas class with a few methods that enable it to work with
the 'htmlize' module.

(You don't need to require() this file yourself. This is done by 'htmlize'.)

]]

-- Like string.len()
function ui.Canvas.meta:len()
  return self:get_cols() * self:get_rows()
end

-- Converts an offset into (x,y) coordinates.
function ui.Canvas.meta:flat_to_xy(pos)
  local x = math.fmod(pos - 1, self:get_cols())  -- "- 1" because the offset is 1-based.
  local y = math.floor((pos - 1) / self:get_cols())
  return x, y
end

-- Like string.sub()
function ui.Canvas.meta:sub(i, j)
  local max = self:len()
  local s = ""
  for n = i, j do
    local x, y = self:flat_to_xy(n)
    s = s .. self:get_char_at(x,y)
    if x == self:get_cols() - 1 then
      s = s .. "\n"
    end
  end
  return s
end

-- Like Editbox.get_style_at()
function ui.Canvas.meta:get_style_at(pos)
  local x, y = self:flat_to_xy(pos)
  local _, style = self:get_char_at(x,y)
  return style and style or 0  -- "0" is the {fg:"default",bg:"default"} style.
end
