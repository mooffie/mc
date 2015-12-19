--[[

Tests the garbage collection portion of the UI module.

Symlink this to your Lua user dir and restart MC. Then hit <F4>.

]]

local function weak_count()
  local tbl = debug.getregistry()['ui.weak']
  local c = 0

  -- For Lua 5.2 it's purportedly enough to GC twice. For 5.1, to stay on the safe side,
  -- we do it twice more. Won't hurt.
  for _ = 1, 4 do
    collectgarbage()
  end

  for k, _ in pairs(tbl) do
    if type(k) == "userdata" then
      c = c + 1
    end
  end
  return c
end

local function test_gc()

  abortive(weak_count() == 0, "Error: You have to start this test with a clean slate. You have other Lua plugins loaded.")

  do
    local b1 = ui.Button("click me")
    assert(weak_count() == 1)
  end

  assert(weak_count() == 0)

  do
    local dlg = ui.Dialog()
    do
      local b1 = ui.Button("click me")
      local b2 = ui.Button("click me")
      local b3 = ui.Button("click me")
      assert(weak_count() == 4)
      dlg:add(b1)
    end
    assert(weak_count() == 2)  -- buttons b2 and b3 are dead.
  end

  assert(weak_count() == 0)

  do
    local btn = ui.Label("Close this dialog.")
    local dlg = ui.Dialog("test"):add(btn)
    dlg.modal = false
    dlg:run()
  end

  assert(weak_count() == 0)

  do
    local btn = ui.Label("Don't close this modaless dialog. Switch to another!")
    local dlg = ui.Dialog("test"):add(btn)
    dlg.modal = false
    dlg:run()
  end

  assert(weak_count() == 2)    -- Note: the widgets aren't garbage collected now.

  alert("Done. After you close this alert-box, switch to the modaless dialog and close it. Then hit F5.")
end

declare('global_dialog')

local function test_gc2()
  assert(weak_count() == 0)
  alert("All is ok.")

  global_dialog = ui.Dialog()
  -- See explanation in ui.lua, "before-vfs-shutdown".
  alert("A final test: We're going to GC a global dialog. Quit MC and see that it doesn't crash.")
end


keymap.bind('f4', test_gc)
keymap.bind('f5', test_gc2)
