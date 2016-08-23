--[[

A ButtonBar widget.

It holds buttons and displays them on one line.

This widget is independent of the tabs module (but kept here for the time
being).

Usage:

    require('samples.accessories.tabs.tbuttonbar')

Then:

    btn = ui.TButtonBar()

    bar:add_button {
      label = 'say hello',
      on_click = function()
        alert 'hello there!'
      end,
    }

]]

local List = utils.table.List

local ButtonBar = ui.Custom.subclass("TButtonBar")

ButtonBar.__allowed_properties = {
  style = true,
  btns = true,
  _selected_button = true,
}

function ButtonBar:init()
  self.style = { normal = 'dialog._default_', selected = 'dialog.dfocus' }
  self.btns = List {}
  self._selected_button = 1
end

----------------------------------- Utils ------------------------------------

function ButtonBar:find_btn_idx(btn)
  for i, b in ipairs(self.btns) do
    if b == btn then
      return i
    end
  end
end

------------------------ Managing the selected button ------------------------

--
-- Accessor
--

function ButtonBar:set_selected_button(btn)
  local i = (type(btn) == "number") and btn or self:find_btn_idx(btn)
  if i then
    self._selected_button = i
    self:redraw()
  end
end

function ButtonBar:get_selected_button()
  return self.btns[self._selected_button]
end

--
-- Select next/prior
--

function ButtonBar:find_next_selectable(from)
  for i = from, #self.btns do
    if self.btns[i].selectable then
      return i
    end
  end
end

function ButtonBar:find_prior_selectable(from)
  for i = from, 1, -1 do
    if self.btns[i].selectable then
      return i
    end
  end
end

function ButtonBar:select_next()
  local i = self:find_next_selectable(self._selected_button + 1) or self:find_next_selectable(1)
  if i then
    self.selected_button = i
  end
end

function ButtonBar:select_prior()
  local i = self:find_prior_selectable(self._selected_button - 1) or self:find_prior_selectable(#self.btns)
  if i then
    self.selected_button = i
  end
end

----------------------------- Add/remove buttons -----------------------------

function ButtonBar:add_button(btn, pos)
  if not pos then
    pos = #self.btns + 1
  end
  if pos < 0 then
    pos = #self.btns - (-pos) + 1
  end
  self.btns:insert(pos, btn)
  self:redraw()
end

function ButtonBar:delete_button(btn)
  local i = self:find_btn_idx(btn)
  if i then
    self.btns:remove(i)
    self:redraw()
  end
end

------------------------------- Mouse support --------------------------------

-- Finds the button at coordinate x.
function ButtonBar:find_screen_btn(x)
  local start = 1
  for i, btn in ipairs(self.btns) do
    local stop = start + tty.text_width(btn.label) + 1
    if x >= start and x <= stop then
      return i
    end
    start = stop + 2
  end
  return nil
end

function ButtonBar:on_mouse_click(x, y, _, count)
  local i = self:find_screen_btn(x)
  if i then
    self.btns[i]:on_click(count)
  end
end

--
-- Drag support
--

local dragged_btn_idx = nil

function ButtonBar:on_mouse_down(x, y)
  dragged_btn_idx = self:find_screen_btn(x)
end

function ButtonBar:on_mouse_drag(x, y)
  local over_btn_idx = self:find_screen_btn(x)
  local over_btn = self.btns[over_btn_idx]
  local dragged_btn = self.btns[dragged_btn_idx]

  if dragged_btn and dragged_btn.selectable and over_btn and over_btn.selectable then
    local selected = self.selected_button
    self.btns:remove(dragged_btn_idx)
    self.btns:insert(over_btn_idx, dragged_btn)
    self.selected_button = selected
    dragged_btn_idx = over_btn_idx  -- for next round.
  end
end

---------------------------------- Drawing -----------------------------------

function ButtonBar:on_draw()

  local c = self:get_canvas()

  local style_normal   = tty.style(self.style.normal)
  local style_selected = tty.style(self.style.selected)

  c:set_style(style_normal)
  c:erase()

  local x = 1

  for i, btn in ipairs(self.btns) do
    c:goto_xy(x, 0)
    if self._selected_button == i then
      c:set_style(style_selected)
    else
      c:set_style(style_normal)
    end
    c:draw_string("[" .. btn.label .. "]")
    x = x + tty.text_width(btn.label) + 2 + 1
  end

end

------------------------------------------------------------------------------
