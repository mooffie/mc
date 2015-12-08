--[[

Adds "read only" support for the Editbox widget.

Usage:

    require('samples.libs.editbox-read-only')
    ...
    edt.read_only = true
    ...

Notes:

This is a "poor man's implementation" of the feature. It's imperfect: it
needs to know the modifying ("black") and non-modifying ("white") keys.
MC should have this feature built-in (see ticket #83).

(The code is based on the example code given in the documentation for
widget:fixate().)

]]

local split = utils.text.tsplit
local List = utils.table.new

local M = {
  white_keys_l = split [[
    esc
  ]],
  black_keys_l = split [[
    C-y C-k f5 f6 f8 M-p backspace delete
  ]]
}

function ui.Editbox.meta:set_read_only(value)
  self.data.is_read_only = value
  self:fixate()
end

function ui.Editbox.meta:get_read_only()
  return self.data.is_read_only
end


local white_keys, black_keys

local function is_modifier(kcode)
   white_keys = white_keys or List(M.white_keys_l):map(tty.keyname_to_keycode):makeset()
   black_keys = black_keys or List(M.black_keys_l):map(tty.keyname_to_keycode):makeset()

   return (kcode < 256) and (not white_keys[kcode]) or black_keys[kcode]
end

ui.Editbox.bind('any', function(edt, kcode)
  if edt.read_only and is_modifier(kcode) then
    tty.beep()
  else
    return false  -- Let MC handle this key.
  end
end)

return M
