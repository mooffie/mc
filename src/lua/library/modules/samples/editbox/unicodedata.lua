--[[

Shows information about a Unicode character:

* Its UnicodeData.txt line.
* Its UTF-8 sequence.

Installation:

Add the following to your startup scripts:

    ui.Editbox.bind('C-x i', function()
      require('samples.editbox.unicodedata').run()
    end)

If you want to specify the path of UnicodeData.txt yourself, instead of
letting us find it for you, do:

    require('samples.editbox.unicodedata').unicodedata_path = '/path/to/UnicodeData.txt'

]]

local M = {
  unicodedata_path = nil,
}

function M.run()

  local edt = assert(ui.current_widget("Editbox"))

  if not M.unicodedata_path then
    M.unicodedata_path = require('prompts').please_wait(T"Searching your system for the UnicodeData.txt file.", function()
       return io.popen("locate -n 1 -e /UnicodeData.txt"):read()
    end)
    abortive(M.unicodedata_path, T"I can't find UnicodeData.txt on your system.")
  end

  local ch, ch_code = edt:get_current_char()

  local hex = ("%04X"):format(ch_code)

  local cmd = ("grep '^%s;' '%s'"):format(hex, M.unicodedata_path)

  local line = io.popen(cmd):read()

  local seq = ch:gsub('.', function(c) return ("\\x%02X"):format(c:byte()) end)

  local info = ([[
Character: %s
Decimal: %d
Hex: %X
UTF-8 sequence: %s

%s]]):format(edt:to_tty(ch), ch_code, ch_code, seq, line)

  -- We don't use alert() because it centers the text :-(
  ui.Dialog(T"Unicode Character Information"):add(ui.Label(info), ui.Buttons():add(ui.OkButton())):run()

end

return M
