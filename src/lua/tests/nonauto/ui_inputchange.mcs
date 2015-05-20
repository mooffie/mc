
local function test()

  local dlg = ui.Dialog("on_change test")

  local ipt = ui.Input{expandx=true}
  local lbl = ui.Label{expandx=true, auto_size=false}
  local grp = ui.Groupbox():add(lbl)

  local updates = 0

  ipt.on_change = function()
    lbl.text = ipt.text
    grp.text = ("Number of updates: %d"):format(updates)
    updates = updates + 1
  end

  dlg:add(
    ui.Label(
[[This dialog checks the Input widget's on_change event.
Type something here and see it updated in the label.]]
    ),
    ui.ZLine(),
    ipt,
    grp
  )

  dlg:run()
end

test()
