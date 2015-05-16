--[[

Draws a scrollbar for the panels.

Installation:

    require('samples.accessories.scrollbar').install()

Or, if you want to customize its appearance:

    local sb = require('samples.accessories.scrollbar')
    sb.style.color.active = 'core.marked'
    sb.style.char.thumb.unicode = '█'
    sb.install()

]]

local scrollbar_utils = require('samples.libs.scrollbar')

local M = {}

M.style = {
  color = {
    active = 'core.header',
    inactive = 'core._default_',
  },
  char = {
    thumb = {
      -- Thick line (┃) is preferable to full block (█) as it's less
      -- distracting. However, the Linux console displays it like a
      -- thin line, making it indistinguishable from the panel's frame.
      unicode = os.getenv('DISPLAY') and '┃' or '█',
      eightbit = nil,
      fallback = 'widget-scollbar.current-char',
    },
  }
}

--
-- Calculates the scrollbar's dimensions.
--
local function calculate_panel_sb(pnl)

  local top_file, body_lines, cols = pnl:_get_metrics()
  local total_items = pnl:_get_max_index()
  local items_visible = body_lines * cols

  return scrollbar_utils.calculate(total_items, items_visible, top_file, body_lines)

end

--
-- There isn't really a reason to put this code inside an install() function.
-- We do this only to be "compatible" with the 'samples.editbox.scrollbar'
-- module, which does have an install() function. Otherwise we'd confuse the
-- user ("why don't I need to call install() for this module too?").
--
function M.install()

  local style = nil

  ui.Panel.bind('<<draw>>', function(pnl)

    -- Compile the style.
    if not style then
      style = scrollbar_utils.compile_style(M.style)
    end

    local top, ht = calculate_panel_sb(pnl)

    if not top then
      return
    end

    local c = pnl:get_canvas()

    if pnl == ui.Panel.current then
      c:set_style(style.color.active)
    else
      c:set_style(style.color.inactive)
    end

    c:fill_rect(pnl.cols - 1, top + 2, 1, ht, style.char.thumb)

  end)

  ui.Panel.bind('<<activate>>', function(pnl)
    -- Redraw the inactive scrollbar in its correct color.
    if ui.Panel.other then
      ui.Panel.other:redraw()
    end
  end)

  event.bind('ui::skin-change', function()
    style = nil
  end)

end

return M
