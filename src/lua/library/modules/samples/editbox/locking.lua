--[[

Alternative file-locking for the editor.

MC's builtin file-locking is so-so. It doesn't warn you when you're
editing a file that's already open in another mcedit instance.

While MC does warn you at the moment you're trying to save your
modifications, it's a great bother having to analyze your modifications
and figure out if you'll be losing modifications made in some other
mcedit instance.

Headache, in short.

The heart of the problem is that MC uses lock files only for the
stretch of time when the text is dirty (when there's "M" in the status
line).

This module solves the problem by provides locking that's active during
the entire editing session!

Installation:

    require('samples.editbox.locking')

]]

local locker = require('samples.libs.locking-impl')

local M = {}

--
-- Formats the message shown to the user.
--
-- You can override this module-function to add more information. E.g.,
-- you can tell the user the desktop number and the terminal tab where
-- the locking process is.
--
function M.format_message(lock_info)
  return T'The file "%s" is already being edited.\n%s\nLock age: %s':format(
    utils.path.basename(lock_info.resource_name),
    (lock_info.pid == os.getpid()) and T"By the current process." or T"By process ID %s":format(lock_info.pid),
    utils.text.format_interval_tiny(lock_info.age)
  )
end

--
-- Asks the user for his choice on what to do.
--
local function ask(lock_info)
  local dlg = ui.Dialog{T"File locked", colorset="alarm"}
  dlg:add(ui.Label(M.format_message(lock_info)))
  dlg:add(ui.Buttons():add(
    ui.Button{T"&Ignore lock",type="default",result="ignore"},
    ui.Button{T"&Grab lock",result="grab"}
  ))
  return dlg:run() or "ignore"
end

ui.Editbox.bind("<<load>>", function(edt)
  if edt.filename then
    if locker.is_locked(edt.filename) then
      if ask(locker.get_lock_info(edt.filename)) == "ignore" then
        edt.data.ignore_lock = true
        edt:fixate()  -- See its documentation.
      else
        locker.lock(edt.filename)
      end
    else
      locker.lock(edt.filename)
    end
  end
end)

ui.Editbox.bind("<<unload>>", function(edt)
  if edt.filename then
    if not edt.data.ignore_lock then
      locker.unlock(edt.filename)
    end
  end
end)

return M
