local append = table.insert

local function test()

  local dir = os.getenv("HOME") or "/"

  local dlg = ui.Dialog(T"File Chooser")
  local lst = ui.Listbox{rows=10}
  local current = ui.Label{cols=50, auto_size=false}

  local function get_files()
    local a = {}
    for f in fs.files(dir) do
      if assert(fs.lstat(dir .. "/" .. f, "type")) == "directory" then
        f = f .. "/"
      end
      append(a, f)
    end
    table.sort(a)
    return a
  end

  lst.items = get_files()
  lst.on_change = function()
    current.text = lst.value
  end

  if lst.value then
    lst:on_change()  -- initialize display.
  end

  dlg:add( ui.Groupbox {T"Files", padding=0}:add(lst) )
  dlg:add( ui.Groupbox(T"Selection:"):add(current) )

  dlg:run()
end

test()
