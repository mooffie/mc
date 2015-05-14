--[[

Extended Label widget.

Is like ui.Label but with the following enhancements:

- Has 'style' attribute.
- Has 'align' attribute.

Usage:

  require('samples.ui.extlabel')

Then:

  lbl = ui.ExtLabel()

]]

local ExtLabel = ui.Custom.subclass("ExtLabel")

ExtLabel.__allowed_properties = {
  _text = true,
  _align = true,
  _style = true,
}

function ExtLabel:init()
  self._text = ""
  self._align = "left"
  self._style = nil
end

function ExtLabel:set_style(stl)
  self._style = stl
  self:redraw()
end

function ExtLabel:set_align(j)
  self._align = j
  self:redraw()
end

function ExtLabel:set_text(s)
  self._text = s
  self:redraw()
end

function ExtLabel:get_text()
  return self._text
end

function ExtLabel:on_draw()
  local c = self:get_canvas()
  if self._style then
    c:set_style(self._style)
  end
  c:erase()

  local cols = self.cols
  local rows = self.rows
  local y = 0

  for line in (self._text .. "\n"):gmatch("([^\n]*)\n") do
    if y < rows then
      c:goto_xy(0,y)

      -- @FIXME: turns out MC's str_*_term_trim(), which is called by
      -- tty.text_align(), can't handle very long strings. It will crash
      -- MC. For the time being let's have this temporary solution:
      if line:len() > 200 then
        line = line:sub(1,100) .. line:sub(-100)
      end

      c:draw_string(tty.text_align(line, cols, self._align))
      y = y + 1
    end
  end
end

-- If this widget somehow got the focus (I encountered this weird situation
-- while working on the docker), at least let the user out. Maybe we should
-- move this to ui.Custom.
function ExtLabel:on_unfocus()
  return true
end
