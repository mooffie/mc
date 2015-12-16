--
-- Utils to ease the writing of screensavers.
--

local M = {}

--
-- Places a widget inside a maximized dialog. The widget too will be maximized,
-- and its size will be adjusted if the user resizes the terminal.
--
function M.wrapper_dialog(widget)
  local dlg = ui.Dialog()
  dlg.on_resize = function(self)
    self:set_dimensions(0, 0, tty.get_cols(), tty.get_rows())
    widget.cols = self.cols
    widget.rows = self.rows
  end
  dlg:on_resize()
  dlg:map_widget(widget)
  return dlg
end

--
-- Generates the function that "installs" the screensaver.
--
function M.create_installer(run)

  -- The function accepts an optional 'timeout' argument which defaults
  -- to one minute.
  return function(timeout)

    local reschedule

    -- 'reschedule' is a function that schedules the screensaver to appear
    -- in X minutes, and cancels all previous schedules.
    reschedule = timer.debounce(function()
      timer.unlock()
      run()
      tty.refresh()
      reschedule()
    end, timeout or 60*1000)

    -- We call it at the start.
    reschedule()

    -- And we call it every time a key is pressed. So effectively we
    -- "postpone" the screensaver on every key.
    keymap.bind('any', function()
      reschedule()
      return false
    end)

  end

end

return M
