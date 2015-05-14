
-- This it a quick imitation of src/filemanager/filegui.c:overwrite_query_dialog()

local function test()

  local bor = require("utils.bit32").bor

  local dlg = ui.Dialog { T"File Exists", colorset = "alarm", padding = 2 }

  local path = "/media/ext/_cdr/ls/one/two/some long path to file here.txt"

  dlg:add(ui.Label { T"Target file already exists!\n" .. path, pos_flags = bor(ui.WPOS_CENTER_HORZ, ui.WPOS_KEEP_TOP) })
  dlg:add(ui.ZLine())
  dlg:add(ui.Label("New     : Aug 30 15:33, size 34"))
  dlg:add(ui.Label("Existing: Oct  9 15:38, size 966"))
  dlg:add(ui.ZLine())
  dlg:add(ui.HBox():add(
    ui.Label(T"Overwrite this target?"), ui.Button(T"&Yes"), ui.Button(T"&No"), ui.Button(T"A&ppend")
  ))
  dlg:add(ui.ZLine())
  dlg:add(ui.HBox():add(
    ui.Label(T"Overwrite all targets?"),
    ui.VBox():add(
      ui.HBox():add(ui.Button(T"&All"), ui.Button(T"&Update"), ui.Button(T"Non&e")),
      ui.Button(T"If &size differs")
    )
  ))

  dlg:add(ui.Buttons():add(ui.Button(T"&Abort")))

  dlg:run()

end

test()
