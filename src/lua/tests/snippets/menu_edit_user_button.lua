--[[

The "Edit menu file" command brings up a dialog with two buttons.
Unfortunately, the "Local" button initially has the focus whereas users
are usually more interested in the "User" button.

This script sets the focus to the "User" button.

]]

ui.Dialog.bind('<<open>>', function(dlg)
  if dlg.text == T'Menu edit' then
    local btn = dlg:find('Button', function (b) return b.text == T'&User' end)
    if btn then
      btn:focus()
    end
  end
end)
