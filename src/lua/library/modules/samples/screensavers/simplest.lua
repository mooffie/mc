
-- This file demonstrates how to write a very simple screensaver.

--[[

  To install, add the following to your startup scripts:

    require('samples.screensavers.simplest').install()

  (or do '.install(5*60*1000)' to kick in after 5 minutes, for example,
  instead of the default 1 minute.)

  We also export a 'run' function. It's optional. It lets users play the
  animation whenever they want, bypassing the screensaver mechanism:

    keymap.bind('C-d', function()
      require('samples.screensavers.simplest').run()
    end)

]]

local wrapper_dialog, create_installer = import_from('samples.screensavers.utils', { 'wrapper_dialog', 'create_installer' })

local function run()
  local greeting = ui.Custom()
  local dlg = wrapper_dialog(greeting)

  greeting.on_draw = function()
    local c = greeting:get_canvas()
    c:set_style(tty.style("yellow, black"))
    c:erase()

    local message = T"Hello World"
    c:goto_xy((greeting.cols - tty.text_width(message))/2, greeting.rows/2)
    c:draw_string(message)
  end

  -- The responsibility to close the dialog on any keypress is ours.
  greeting.on_hotkey = function()
    dlg:close()
    return true
  end

  dlg:run()
end

return {
  run = run,
  install = create_installer(run),
}
