--[[

Lets you move a dialog on the screen with shift + arrow keys.

It was originally written as an aid for creating better screenshots, but it
turns out it's useful in itself: sometimes dialogs (e.g., the editor's
"replace" dialog, copy/move progress dialog) obscure important data and we
want them out of the way.

NOTE: It also works on top-level dialogs. E.g., the filemanager and the
editor. You'll see "garbage" underneath when you move them, but it's not a bug.

]]

local function enabled()
  -- In the future we may want to turn off this feature for certain dialogs/widgets.
  return true
end

local function do_move(translate)
  if enabled() then
    local dlg = ui.Dialog.top
    translate(dlg)
    for wgt in dlg:gmatch() do
      translate(wgt)
    end
    tty.redraw()
    return true
  else
    return false
  end
end

keymap.bind('S-left', function()
  return do_move(function(wgt) wgt.x = wgt.x - 1 end)
end)

keymap.bind('S-right', function()
  return do_move(function(wgt) wgt.x = wgt.x + 1 end)
end)

keymap.bind('S-up', function()
  return do_move(function(wgt) wgt.y = wgt.y - 1 end)
end)

keymap.bind('S-down', function()
  return do_move(function(wgt) wgt.y = wgt.y + 1 end)
end)