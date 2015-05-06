--[[

This file contains the code that drives 'mcscript' (or 'mc --script').

]]

local M = {}

M.wallpaper = {
  --
  -- Alas, it seems that it takes "long" for gnome-terminal to draw this UTF-8
  -- character.
  --
  -- It makes scrolling the list in tests/manual/ui_filechooser.lua sluggish. The
  -- background's on_draw() isn't even being called.
  --
  -- @todo: check if it's just a matter of gnome-terminal queuing the screen
  -- updates or whether the CPU is actually utilized. If the latter, we'll
  -- have to use a plain space character instead :-(
  --
  char = tty.is_utf8() and '▒' or ' ',
  style = 'core._default_',
}

--
-- Creates the "wallpaper" for UI applications. It's just a dialog
-- that covers the whole background.
--
local function create_wallpaper()
  local dlg = ui.Dialog()

  function dlg:on_resize()
    self:set_dimensions(0, 0, tty.get_cols(), tty.get_rows())
  end
  dlg:on_resize()

  function dlg:on_draw()
    local c = self:get_canvas()
    c:set_style(tty.style(M.wallpaper.style))
    c:erase(M.wallpaper.char)
    return true
  end

  return dlg
end

--
-- A wrapper around coroutine.resume().
--
local function resume(co)
  local success, result

  if tty.is_ui_ready() then
    local wallpaper = create_wallpaper()
    wallpaper.on_idle = function()
      wallpaper.on_idle = nil
      success, result = coroutine.resume(co)
      wallpaper:close()
    end
    wallpaper:run()
  else
    success, result = coroutine.resume(co)
  end

  return success, result
end


local script = nil

--
-- The heart of mcscript.
--
-- This function is registered with the C side in _bootstrap.lua. It's
-- called by MC.
--
function M.run_script(pathname)

  --
  -- Load the script.
  --

  if pathname then
    devel.log("mcscript: running " .. pathname)

    local fn, errmsg = loadfile(pathname)
    if not fn then
      -- "2" here and bellow means: don't prepend ".../core/mcscript.lua" to the error message.
      error(errmsg, 2)
    end

    script = coroutine.create(fn)
  end

  assert(script, E"Invalid invocation of run_script(). You must provide a valid pathname on the first run.")

  --
  -- Run the script.
  --

  if coroutine.status(script) == "dead" then
    return
  end

  local success, result = resume(script)
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
    return true
  end

end

return M
