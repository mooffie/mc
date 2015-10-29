--[[

Makes an editbox read-only.

(This snippet is based on the example code given in the documentation for
widget:fixate().)

]]

-- Let the user toggle the state with C-n.
ui.Editbox.bind('C-n', function(edt)
  edt.read_only = not edt.read_only
  tty.beep()
end)

-- If we don't have write access to the file, start as read only.
ui.Editbox.bind('<<load>>', function(edt)
  if edt.filename and not fs.nonvfs_access(edt.filename, 'w') then
    edt.read_only = true
  end
end)


------------------------------- Implementation -------------------------------

local split = utils.text.tsplit
local List = utils.table.new


function ui.Editbox.meta:set_read_only(value)
  self.data.is_read_only = value
  self:fixate()
end

function ui.Editbox.meta:get_read_only()
  return self.data.is_read_only
end

local white_keys_l = split [[
  esc
]]
local black_keys_l = split [[
  C-y C-k f5 f6 f8 M-p backspace delete
]]

local white_keys = List(white_keys_l):map(tty.keyname_to_keycode):makeset()
local black_keys = List(black_keys_l):map(tty.keyname_to_keycode):makeset()

local function is_modifier(kcode)
   return (kcode < 256) and (not white_keys[kcode]) or black_keys[kcode]
end

ui.Editbox.bind('any', function(edt, kcode)
  if edt.read_only and is_modifier(kcode) then
    tty.beep()
  else
    return false  -- Let MC handle this key.
  end
end)
