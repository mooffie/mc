--[[

This module provides a find-as-you-type functionality for listboxes.

Installation:

Add the following to your startup scripts:

    ui.Listbox.bind('C-s', function()
      require('samples.accessories.find-as-you-type').run()
    end)

(Of course, you may choose a different key than C-s.)

Search is case insensitive if you type only lower case letters. If you
type an upper case letter, it becomes case sensitive.

]]

local function find(items, needle, from)

  local case_sensitive = (needle ~= needle:lower())

  for i = from, #items do
    local item = items[i]
    if type(item) == "table" then  -- handle items of the form { "Read only", value="ro" }
      item = item[1]
    end
    if not case_sensitive then
      item = item:lower()
    end
    if item:find(needle) then
      return i
    end
  end

  -- Wrap around: If we were searching from the middle, try again, but now from the start of the list.
  if from ~= 1 then
    return find(items, needle, 1)
  end

end

local function run()

  local lst = assert(ui.current_widget("Listbox"), E"I can work on listboxes only.") -- The API is compatible with radios too, but who cares...

  local dlg = ui.Dialog { T"Search:", compact=true }
  local ipt = ui.Input()

  dlg:add(ipt)

  dlg:set_dimensions(
    lst.x,
    math.min(lst.y + lst.rows, tty.get_rows() - dlg:preferred_rows() + 1) -- Makes sure the box isn't outside the screen.
  )

  ipt.on_change = function(self)
    local i = find(lst.items, ipt.text, lst.selected_index)
    if i then
      -- Note the order: first we update the listbox, then the dialog.
      -- If we switch the order, the listbox can draw itself on top of the
      -- the dialog (no problem: we could fix this by calling dlg:redraw() next).
      lst.selected_index = i
      dlg.colorset = "normal"
    else
      dlg.colorset = "alarm"
    end
  end

  dlg.on_key = function(self, key)
    if key == tty.keyname_to_keycode('C-s') then
      -- Find the next item.
      if find(lst.items, ipt.text, lst.selected_index + 1) then
        lst.selected_index = lst.selected_index + 1
        ipt:on_change()
      end
      return true
    end
  end

  dlg:run()

end

return {
  run = run,
}
