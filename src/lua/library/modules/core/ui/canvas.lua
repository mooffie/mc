--[[

The functions here are implemented in Lua for the sake of
experimentation.

Once functions are well-tested and proven to be useful we may want to
move them to the C side.

]]

--- @classmod ui.Canvas

local ui = require("c.ui")

---
-- Draws a string, clipped.
--
-- We explained in the introduction that the canvas doesn't inherently
-- performs clipping.
--
-- This makes matters awkward when you simply want to print a string that
-- may overflow the canvas' area.
--
-- This utility function comes to your rescue. It does the clipping (or
-- "trimming") for you: it ensures that no part of the string is drawn
-- outside the canvas area.
--
-- You must provide __x__ and __y__, the coordinates at which to start
-- drawing the string (they may well be outside the canvas; i.e., negative
-- numbers are allowed). You may also clip the string further to within a
-- (virtual) column in your canvas by supplying its left (__x1__) and right
-- (__x2__) edges.
--
-- @function draw_clipped_string
-- @args (x, y, string[, x1[, x2])
function ui.Canvas.meta:draw_clipped_string(x, y, s, x1, x2)

  if y < 0 or y >= self:get_rows() then
    return
  end

  local self_cols = self:get_cols()

  -- fix x1.
  x1 = math.max(x1 or 0, 0)

  -- fix x2.
  x2 = math.min(x2 or self_cols, self_cols)

  -- clip on the left.
  if x < x1 then
    s = tty.text_cols(s, x1 - x + 1)
    x = x1
  end

  -- clip on the right.
  local remaining_width = math.max(x2 - x, 0)
  s = tty.text_cols(s, 1, remaining_width)

  self:goto_xy(x, y)
  self:draw_string(s)
end

---
-- Erases the canvas' contents.
--
-- This utility function simply calls fill_rect() over the whole canvas'
-- area and positions the cursor at the top-left corner.
--
-- @function erase
-- @param[opt] filler  Optional. A character to use instead of space.
--
function ui.Canvas.meta:erase(filler)
  self:fill_rect(0, 0, self:get_cols(), self:get_rows(), filler)
  self:goto_xy(0, 0)
end
