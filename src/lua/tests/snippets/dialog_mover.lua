--[[

Lets you move dialogs on the screen with shift + arrow keys.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!                                                                     !
! There's now a module that lets you drag dialogs with the mouse:     !
!                                                                     !
!  require('samples.accessories.dialog-drag').install()               !
!                                                                     !
! But, for "educational" purposes, we'll still keep this snippet. It  !
! also lets you use the keyboard, something which isn't supported by  !
! the aforementioned module.                                          !
!                                                                     !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

It was originally written as an aid for creating better screenshots, but
it turns out it's useful in itself: sometimes dialogs (e.g., the editor's
"replace" dialog, copy/move progress dialogs) obscure important data and
we want them out of the way.

NOTE: It also works on top-level dialogs. E.g., the filemanager and the
editor. You'll see "garbage" underneath when you move them, but this is
not a bug.

]]

local function can_move(dlg)
  -- In the future we may want to turn off this feature for certain dialogs.
  return true
end

local function do_move(translate)
  local dlg = ui.Dialog.top
  if can_move(dlg) then
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
