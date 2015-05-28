--[[

Tweaks the way listboxes respond to keys.

About:

Normally, listboxes let you select the top 10 items by typing "0" to "9".
This snippet changes this by letting you type "1" to "9" and "A" to "Z".

Idea taken from:

    https://mail.gnome.org/archives/mc-devel/2015-May/msg00055.html

]]

local K = utils.magic.memoize(tty.keyname_to_keycode)

ui.Listbox.bind('any', function (lst, kcode)

  abortive(kcode ~= nil, E"Sorry, you seem to be using an ancient version of our Lua API. Please upgrade.")

  -- Listboxes sometimes have hotkeys associated with items (as in the
  -- "User menu"). We need to try them first:
  if lst:_send_message(ui.MSG_HOTKEY, kcode) then
    -- Yep, the listbox consumed this key.
    return
  end

  local index =
    (kcode >= K'1' and kcode <= K'9') and (kcode - K'1' + 1) or
    (kcode >= K'A' and kcode <= K'Z') and (kcode - K'A' + 10) or false

  if index then
    lst.selected_index = index
    return
  end

  return false  -- 'false' means: let the listbox handle all other keys (arrows, home, delete, etc.)

end)
