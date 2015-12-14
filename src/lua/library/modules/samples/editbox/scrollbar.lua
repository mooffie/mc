--[[

Draws a scrollbar in the editor.

Installation:

    require('samples.editbox.scrollbar').install()

Or, if you want to customize its appearance:

    local sb = require('samples.editbox.scrollbar')
    sb.style.color.thumb = 'core.header'
    sb.style.char.thumb.unicode = '┃'
    -- You may find a west-aligned scrollbar (a la emacs) to be
    -- more convenient as it's closer to the text:
    sb.region = 'west'
    sb.install()

]]

local scrollbar_utils = require('samples.libs.scrollbar')
local docker = require('samples.libs.docker-editor')

local M = {
  style = {
    color = {
      thumb = 'editor.editframeactive',
      trough = 'editor._default_',
      disabled = 'editor._default_',
    },
    char = {
      thumb = {
        unicode = '█',
        eightbit = nil,
        fallback = { 'widget-scollbar.current-char', '*' },
      },
      trough = {
        unicode = '│',
        eightbit = nil,
        fallback = { 'widget-scollbar.background-char', '|' },
      },
      disabled = {
        unicode = '░',  -- darker version: '▒'
        eightbit = ':',
      },
    }
  },
  region = 'east',
}

local style = nil

--
-- Note: We use rawset/get in several places because, by default, the
-- "properties" mechanism of widgets protects againt typos by raising
-- exceptions when setting/getting unknown properties.
--
-- (Alternavitely, we could store 'scrollbar' as a field in the 'data'
-- property, and subclass ui.Custom and define the update() method in
-- the conventional way. This is left as an exercise for the reader.)
--

local function scrollbar_constructor(dlg)

  local sb = ui.Custom{cols=1}

  -- Store it in the dialog so we can refer to it later.
  rawset(dlg, 'scrollbar', sb)

  rawset(sb, 'update', function(self, edt)

    if not style then
      style = scrollbar_utils.compile_style(M.style)
    end

    local c = self:get_canvas()

    -- Some might argue that we could do some optimizations here.
    --
    -- E.g., 'edt:get_max_line()' etc. would be faster than 'edt.max_line'.
    -- And we might want to compare 'top'/'ht' to their previous values to
    -- see if there's any change.
    --
    -- HOWEVER, one must first do some benchmarking, to see if there's any
    -- justification for this "optimization". There probably isn't any: Lua
    -- is fast enough as it is.

    -- Note: 'self.rows' differs from 'edt.rows' when the editbox isn't "fullscreen".
    local top, ht = scrollbar_utils.calculate(edt.max_line, edt.rows, edt.top_line, self.rows)
    if top then
      c:set_style(style.color.trough)
      c:erase(style.char.trough)
      c:set_style(style.color.thumb)
      c:fill_rect(0,top,1, ht, style.char.thumb)
    else
      c:set_style(style.color.disabled)
      c:erase(style.char.disabled)
    end

  end)

  return sb

end

function M.install()

  docker.register_widget(M.region, scrollbar_constructor)

  ui.Editbox.bind('<<draw>>', function(edt)
    local dlg = edt.dialog
    local sb = rawget(dlg, 'scrollbar')
    -- Just before restarting Lua, the docker destroys all the injected
    -- widgets and redraws the editor without them. So we have to check
    -- that the scrollbar is indeed alive.
    if sb and sb:is_alive() then
      sb:update(edt)
    end
  end)

  event.bind('ui::skin-change', function()
    style = nil
  end)

end

return M
