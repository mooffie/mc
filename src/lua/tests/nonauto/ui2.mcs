
local function test()

  local dlg = ui.Dialog(T"Test")

  local gg = ui.Gauge()
  local btnStart = ui.Button(T"Start")

  local interval
  interval = timer.set_interval(function()
      gg.value = gg.value + 1
      if gg.value == 100 then
        interval:stop()
        btnStart.text = T"(Finished)"
        btnStart.enabled = false
      end
      dlg:refresh()
  end, 10):stop()

  dlg:add(gg)

  btnStart.on_click = function(self)
    interval:toggle()
    self.text = interval.stopped and T"Resume" or T"Stop"
    dlg:redraw() -- when the label is shortened, the dialog should paint the background.
  end

  local btnClose = ui.Button { T"Close", result = false }

  dlg:add(ui.Buttons():add(btnStart, ui.Space(5), btnClose))

  dlg:run()
  interval:stop()

end

test()
