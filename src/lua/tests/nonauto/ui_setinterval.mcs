
local function test()
  local dlg = ui.Dialog("blah blah")

  local lbl = ui.Label("0")
  local itvl

  dlg:add(lbl)

  dlg:add(ui.Button{"stop/resume", on_click = function(self)
    if itvl.stopped then
      itvl:resume()
    else
      itvl:stop()
    end
  end})

  dlg:add(ui.DefaultButtons())

  itvl = timer.set_interval(function()
    lbl.text = lbl.text + 1
    dlg:refresh()
  end, 100)

  dlg:run()
  itvl:stop()

--[[

What will happen if we don't call itvl:stop() ?

The interval's function will simply continue to run (add "print
'whatever'" to verify this): it will keep updating the label. Since that
function also references the dialog ("dlg:refresh()"), the dialog will
never be garbage collected.

If we remove the reference to the dialog, the dialog at some point will
be garbage collected (you can hasten this by calling dlg:_destroy()). The
label then too will be destroyed (only the C counterpart, not the Lua
envelope), so setting the label's text will then result in an exception, "A
living widget was expected, but an already destroyed widget was
provided".

]]

end

test()
