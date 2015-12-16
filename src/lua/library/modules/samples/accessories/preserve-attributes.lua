--[[

Unchecks or checks the "Preserve attributes" checkbox in the Move/Copy dialogs.

Installation:

    local pa = require('samples.accessories.preserve-attributes')

    --
    -- And then, for example:
    --

    -- Turn off the checkbox when copying to the USB stick and the camera:
    pa.forget.target = {
      '/media/stick',
      '/media/camera',
    }

    -- Turn off the checkbox when copying *from* the CDROM:
    pa.forget.source = {
      '/media/cdrom/',
    }

    -- These strings are Lua patterns. We should have put "^" in
    -- front but we were lazy.

    -- There's also the `pa.keep.source` and `pa.keep.tagret` tables to
    -- turn *on* the checkbox.

]]

local M = {
  keep = {
    source = {},
    target = {},
  },
  forget = {
    source = {},
    target = {},
  },
}

ui.Dialog.bind('<<open>>', function(dlg)

  if dlg.text == T'Move' or dlg.text == T'Copy' then

    local source = dlg:find('Input', 1)
    local target = dlg:find('Input', 2)
    local chk = dlg:find('Checkbox', function(w) return w.text == T'Preserve &attributes' end)

    if not target then
      -- We're probably in a dialog showing the progress gauge.
      return
    end

    abortive(chk, E"Internal error. I can't see the 'Preserve attributes' checkbox.")

    local function match(patterns, s)
      for _, pat in pairs(patterns) do
        if s:find(pat) then
          return true
        end
      end
    end

    local source_s = fs.VPath(source.text).str  -- Convert to absolute path.
    local target_s = fs.VPath(target.text).str

    if match(M.keep.target, target_s) or match(M.keep.source, source_s) then
      chk.checked = true
    end

    if match(M.forget.target, target_s) or match(M.forget.source, source_s) then
      chk.checked = false
    end

  end

end)

return M
