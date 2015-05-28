--[[

Changes the way listboxes respond to digits.

About:

Normally, listboxes let you select the top 10 items by typing "0" to "9".
This snippet changes this by letting you type "1" to "99".

In short, it's for crazy people who find it easier to count to 30 instead
of just going there with the arrows.

For example, lets say the user types "23". Right after the first "2" is
typed, the listbox jumps to the 2'nd item. Then, if the "3" comes shortly
(within less than 800 milliseconds by default), it jumps to the 23'th
item.

The code contains a few guards to prevent a few scenarios that can make
one very angry. For example, if the listbox (mentioned above) doesn't
have 23 items, the code figures out that you want the 3'rd item.

Idea based on:

    https://mail.gnome.org/archives/mc-devel/2015-May/msg00055.html

]]

local K = utils.magic.memoize(tty.keyname_to_keycode)

local M = {
  window = 800,  -- How many milliseconds to wait between keys for them to be considered a number.
}

local previous = { digit = nil, timestamp = 0 }

ui.Listbox.bind('any', function (lst, kcode)

  -- First, check hotkeys (see explanation in listbox_AZ.lua).
  if lst:_send_message(ui.MSG_HOTKEY, kcode) then
    return
  end

  local digit = (kcode >= K'0' and kcode <= K'9') and (kcode - K'0') or false

  if digit then

    if timer.now() - previous.timestamp < M.window then
      --tty.beep()  -- for debugging.
      if previous.digit then
        digit = previous.digit * 10 + digit
        previous.digit = nil  -- Don't support more than 99. When people type "214" in succession it's likely they want the 4'th item.
      end
    end

    previous.timestamp = timer.now()
    previous.digit = digit

    if digit > #lst.items then
      digit = digit % 10  -- When people type "23" in a list containing just 5 items, they probably want the 3'rd item.
    end

    lst.selected_index = digit
    return

  end

  return false  -- 'false' means: let the listbox handle all other keys (arrows, home, delete, etc.)

end)

return M
