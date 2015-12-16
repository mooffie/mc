--[[

Adds "hotkeys" support to the directory hotlist dialog.

Installation:

    require('samples.accessories.hotlist-keys')

About:

Some users ask for the ability, in the directory hotlist dialog, to
associate keys with directories. This module lets you embed key names in
labels of directories *and* groups. You can then press these keys to
activate the item.

You embed key names by wrapping them in square brackets; e.g.:

    /usr/share/[y]acas
    /[e]tc
    ->logins [f2]
    /media/c/books [C-b]
    [M-g] /usr/lib/ruby/gems/1.8/gems

(Don't worry, you can't corrupt the paths: what you're seeing in the
hotlist dialog is just the labels. The original paths aren't affected.)

Since the hotlist dialog doesn't let you edit labels of existing items
(only of new ones), we provide you with a "Raw" button (to the left of
the "Cancel" button) which opens the textual database in an editor, where
you can modify old labels.

Known issues:

- The keys are in effect only when the focus is in the listbox.

Tips:

- [a] and [A] are two different keys.

- You won't see an error message if you embedded an invalid key name.
  That's because we don't want to bother you with messages about things
  that accidentally look like key names. If you want to verify that your
  key name is indeed valid, open up the calculator and type into it (for
  example):

      tty.keyname_to_keycode 'm-f2'

  You'll see an error message if the key name is invalid.

]]

----------------------------------- Utils ------------------------------------

local function is_hotlist_dialog(dlg)
  return dlg.text == T'Directory hotlist'
end

--
-- Looks for "/some/path/ [keyname]" items in a listbox and returns the
-- index of the first that matches kcode.
--
local function search_hotkey(lst, kcode)
  local items = lst.items

  for i = 1, #items do
    local item = items[i]
    local keyname = item:match '%[(.-)%]'

    if keyname then
      -- We use pcall() because we don't want to bother the user with
      -- exceptions on things that accidentally look like keynames.
      local ok, item_kcode = pcall(tty.keyname_to_keycode, keyname)
      if ok then
        if item_kcode == kcode then
          return i
        end
      else
        devel.log(E'hotlist-keys: Invalid keyname %s':format(keyname))
      end
    end

  end

end

--------------------------------- The crux! ----------------------------------

--
-- Whenever a key is presses in a listbox, search for an item with the
-- matching keyname and simulate pressing it.
--
ui.Listbox.bind('any', function(lst, kcode)

  if is_hotlist_dialog(lst.dialog) then
    local i = search_hotkey(lst, kcode)
    if i then
      lst.selected_index = i
      -- Simulate pressing enter:
      lst.dialog:_send_message(ui.MSG_UNHANDLED_KEY, tty.keyname_to_keycode 'enter')
      -- In case we've entered a group, we need to refresh the display:
      tty.redraw()
      tty.refresh()
      -- By not returning 'false' here we tell the system that we've handled the key.
      -- Otherwise, pressing 'a', for example, will also trigger the "&Add" button.
      return
    end
  end

  return false

end)

-------------------------------- "Raw" button --------------------------------
--
-- Adds a "Raw" button to the dialog.
--

ui.Dialog.bind('<<open>>', function(dlg)

  if is_hotlist_dialog(dlg) then

    local btn_cancel = dlg:find('Button', function(b) return b.text == T'&Cancel' end)

    if btn_cancel then

      local btn_raw = ui.Button{T'Ra&w', pos_flags = utils.bit32.bor(ui.WPOS_KEEP_RIGHT, ui.WPOS_KEEP_BOTTOM)}

      -- When injecting a button to a dialog created in C we need to keep a
      -- reference to the button in a long living variable because otherwise
      -- the object, together with its on_click handler (which is our button's
      -- raison d'être), gets garbage collected (as it's referenced nowhere).
      --
      -- (It won't lead to segfault if we don't do this. It's just that nothing
      -- will happen when we click the button.)
      --
      -- As an alternative to a long living variable, we use :fixate().
      btn_raw:fixate()

      -- We position it to the left of the "Cancel" button.
      btn_raw.x = btn_cancel.x - btn_raw.cols - 1
      btn_raw.y = btn_cancel.y

      -- A mapped widget's 'x' and 'y' properties are in absolute screen
      -- coordinates. Dialog:map_widget(), however, expects (x,y) to be
      -- relative to the dialog's top-left corner. That's why we subtract
      -- the dialog's (x,y).
      btn_raw.x, btn_raw.y = btn_raw.x - dlg.x, btn_raw.y - dlg.y

      btn_raw.on_click = function(self)
        self.dialog:close()
        mc.edit(conf.path('hotlist'))
      end

      dlg:map_widget(btn_raw)

      dlg:find('Listbox'):focus()  -- Move focus back the the listbox.

    end

  end

end)

------------------------------------------------------------------------------
