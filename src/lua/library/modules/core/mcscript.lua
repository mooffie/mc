--[[

This file contains the code that drives 'mcscript' (or 'mc --script').

]]

local M = {}

local script = nil

--
-- The heart of mcscript.
--
-- This function is registered with the C side in _bootstrap.lua. It's
-- called by MC.
--
-- It's called for the first time with a pathname, and it may be called
-- again, with nil, to continue the execution of the previously started
-- script.
--
function M.run_script(pathname)

  --
  -- Load the script.
  --

  if pathname then
    -- First run.
    devel.log("mcscript: running " .. pathname)
    local fn, errmsg = loadfile(pathname)
    if not fn then
      -- "2" here and bellow means: don't prepend ".../core/mcscript.lua" to the error message.
      error(errmsg, 2)
    end
    script = coroutine.create(fn)
  else
    -- Second run.
    assert(script, E"Invalid invocation of run_script(). You must provide a valid pathname on the first run.")
  end

  --
  -- Run the script.
  --

  if coroutine.status(script) == "dead" then
    return
  end

  local success, result = coroutine.resume(script)
  if not success then
    -- We can't do just `error(result, 2)` because the user then won't see
    -- a useful stack trace.
    --
    -- One glitch is that we get to see two "stack traceback:" sections (the
    -- second useless) because on the C side we call debug.traceback() too.
    --
    error(debug.traceback(script, result), 2)
  end

  if result == "continue" then
    -- Signal the C side to run us again when the UI is ready.
    -- See ui.open().
    return true
  end

end

return M
