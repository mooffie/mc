--- Development utilities.
-- @module devel

local devel = {}

require('utils.magic').setup_autoload(devel)
devel.autoload('ensure', 'devel.ensure')
devel.autoload('log', { 'devel.log', 'log' })

---
-- Sends SIGSTOP to the MC process.
--
-- This causes a debugger (e.g., GDB) to kick in. This lets you examine the C
-- stack trace and variables to understand why some Lua code was called.
--
-- Additionally, before the signal is sent, the Lua stack trace is printed out
-- using @{log}.
--
-- Note-short: This is intended for MC's core C developers. Others will find
-- no use for this function.
--
-- Info: If no debugger is running, MC will just seem to hang.
-- do `kill -SIGCONT {pid}` to resume the process.
--
function devel.stop()
  devel.log("\n----------------------\n" .. debug.traceback(2))
  os.kill(os.getpid(), "SIGSTOP")
end

---
-- "Pretty prints" a value. It doesn't actually do any printing: it returns a string.
--
-- This function can handle complex structures: circular references in
-- tables are supported.
--
-- Example:
--
--    devel.log( devel.pp(fs) )
--
-- See also @{devel.view}, which you'll more often use.
--
-- @function pp
-- @args (v)

devel.autoload('pp', { 'devel.pp', 'pp' })

---
-- "Pretty prints" a value into the viewer.
--
-- Example:
--
--    keymap.bind('C-y', function()
--      devel.view(_G)
--    end)
--
-- Note-short: If the UI is not ready, the output will be written to stdout.
--
-- @args (v)
function devel.view(v, pp)
  if tty.is_ui_ready() then
    -- @todo: Once we have mc.view_string() we won't need to use a temporary file.
    local f, tempname = fs.temporary_file{prefix="devel"}
    f:write((pp or devel.pp)(v))
    f:close()
    mc.view(tempname)
    fs.unlink(tempname)
  else
    print(devel.pp(v))
  end
end

local suppressed_errors = {}

--
-- This function is registered with the C side, in _bootstrap.lua, as the one
-- responsible for displaying exceptions to the user.
--
-- See 'capi-safecall.c'.
--
function devel.display_error(msg)

  -- While uncommon, opening this error dialog may again trigger an
  -- exception (e.g., when we have some error in a <<dialog::open>>
  -- event handler. So first thing we do is log the exception so the
  -- user has a foolproof way to see it.
  devel.log(E"EXCEPTION: %s":format(msg))

  local msg_id = msg:match('[^\n]*')

  msg = msg:gsub('\t', '  ')  -- the Label widget can't show tabs.

  if suppressed_errors[msg_id] then
    return
  end

  local ui = require("ui")
  local dlg = ui.Dialog {T"Lua error", colorset = "alarm" }
  local suppress = ui.Checkbox(T"&Don't show this specific error again")

  -- As mentioned above, opening this dialog may trigger a new exception and
  -- so forth ad infinitum. So we tell modules that decorate dialogs (modules
  -- which may have bugs in their <<dialog::open>> etc.) to to lay their
  -- hands off us:
  dlg.data.skip_pyrotechnics = true

  dlg:add(
    ui.Label(T"An error occurred while executing Lua code."),
    ui.ZLine(),
    ui.Label(msg),
    ui.ZLine(),
    suppress,
    ui.Buttons():add(ui.OkButton())
  )

  dlg.on_validate = function()
    if suppress.checked then
      suppressed_errors[msg_id] = true
    end
    return true
  end

  dlg:run()

  -- Usually, we'd do the checkbox processing after dlg:run() returns.
  -- However, if the error was raised in an on_draw event, closing the dialog
  -- will trigger it again (as the screen re-draws) and we'll never reach
  -- "after dlg:run() returns". So instead we do our stuff in on_validate.
end

--
-- Similar to display_error(), except that it's intended for "benign" errors.
--
-- See 'capi-safecall.c'.
--
function devel.display_abort(obj)
  local msg = obj.message
  local ui = require("ui")
  ui.Dialog(T"Abort")
    :add(ui.Label(tostring(msg)))
    :add(ui.Buttons():add(ui.OkButton()))
    :run()
end

return devel
