--[[

The "Edit menu file" command brings up a dialog with two buttons.
Unfortunately, it's the "Local" button which initially has the focus
whereas users are usually more likely to want to hit the "User" button.

This script solves the problem by moving the focus to the "User" button.

See also:

    https://www.midnight-commander.org/ticket/3493
    "Switch 'Local'/'User' buttons on menu selector"

]]

ui.Dialog.bind('<<open>>', function(dlg)
  if dlg.text == T'Menu edit' then
    local btn = dlg:find('Button', function (b) return b.text == T'&User' end)
    if btn then
      btn:focus()
    end
  end
end)

--[[

An alternative approach is to make some key directly launch the editor
with your menu file:

    --
    -- Makes alt-pgdn edit your user menu.
    --
    keymap.bind('M-pgdn', function()
      mc.edit(conf.path('menu'))
    end)

]]
