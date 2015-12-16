--[[

Scrollbar-related utilities.

This is *not* a scrollbar widget. These are utility functions that make it
easy to draw one.

]]

local M = {}

--
-- Calculates the top and height of the scrollbar's thumb.
--
-- Returns the two values, or nothing if no scrollbar should be displayed.
--
-- Note: 'top_item' is expected to be 1-based !
--
function M.calculate(total_items, visible_items, top_item, sb_size)

  top_item = top_item - 1

  if total_items <= visible_items then
    return
  end

  local height = math.floor((visible_items / total_items) * sb_size)  -- range: [0..sb_size)   (Guaranteed to be smaller than 'sb_size', which is good.)

  if height == 0 then  -- When there are gazillion items.
    height = 1
  end

  local top = math.floor((top_item / total_items) * sb_size)  -- range: [0..sb_size)

  local at_bottom = (top_item >= total_items - visible_items)

  if at_bottom then
    -- If the last item is visible, we flush the bar down to
    -- let the user know there are no more items beyond.
    --
    -- On a common terminal (40 lines), this is the only case when
    -- the bar is fully down, unless you have more than 1500 items.
    top = sb_size - height
  end

  return top, height

end

--
-- "Compiles" a style table.
--
-- See the table(s) at accessories/scrollbar.lua or editbox/scrollbar.lua.
--
function M.compile_style(pre)
  local style = {
    color = utils.table.map(pre.color, tty.style),
    char = {}
  }
  for name, C in pairs(pre.char) do
    style.char[name] = (tty.is_utf8() and C.unicode) or
                       C.eightbit or
                       tty.skin_get(C.fallback[1], C.fallback[2])
  end
  return style
end

return M
