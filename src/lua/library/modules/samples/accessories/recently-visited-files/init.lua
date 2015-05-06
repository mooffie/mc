--[[

"Recently visited files"

A dialog that offers easy navigation in recently edited or viewed files.

See the help file!

Installation:

    keymap.bind('M-pgup', function()
      require('samples.accessories.recently-visited-files').run()
    end)

]]

local db_build, db_delete_record = import_from('samples.accessories.recently-visited-files.db', { 'build', 'delete_record' })

local M = {
  last_filter = nil,
  last_path = nil,
}

function M.run()

  if not ui.Panel.current then
    abort(E"Sorry, you can't use this app with mcedit. See discussion about MC bug in the source code.")
  end

  if ui.Dialog.top.data and ui.Dialog.top.data.is_recently_visited_dialog then
    return  -- The dialog is already open.
  end

  local dlg = ui.Dialog(T'Recently visited files')

  ------------------------------ Listbox setup -------------------------------

  local fltr = ui.Input{M.last_filter, expandx=true}
  local lst = ui.Listbox{expandx=true, expandy=true, rows=2}

  local db = db_build()

  -- Selects a certain path in the listbox.
  local function select_by_path(path)
    local rec = lst.items:filter(function(rec) return rec.value.path == path end)[1]
    if rec then
      lst.value = rec.value
    end
  end

  -- Populates the listbox. It applies the filter to the DB.
  local function rebuild_items()
    local val = lst.value
    lst.items = db:filter(function(rec) return rec[1]:find(fltr.text, 1, true) end)
    lst.value = val
  end

  rebuild_items()
  fltr.on_change = rebuild_items

  -- When opening the dialog we go and stand on the path on which we last
  -- stood. Unless we're inside thw editor, in which case we stand on the
  -- file being edited.
  select_by_path(M.last_path)
  if ui.current_widget('Editbox') then
    select_by_path(ui.current_widget('Editbox').filename)
  end

  ---------------------------- Layout and buttons ----------------------------

  dlg:add(ui.Groupbox{T'Quick filter'}:add(fltr))
  dlg:add(ui.Groupbox{T'Files:', expandy=true}:add(lst))
  dlg:add(ui.Buttons():add(
    ui.Button{T'&Edit - F4', type='default', result='edit'},
    ui.Button{T'&View - F3', result='view'},
    ui.Button{T'&Goto', result='goto', enabled=ui.Panel.current},
    ui.Button{T'De&lete', on_click=function()
      if lst.value then
        local pos = lst.selected_index
        db = db_delete_record(db, lst.value.path)
        rebuild_items()
        lst.selected_index = math.min(pos, #db)
      end
    end},
    ui.CancelButton(),
    ui.Space(),
    ui.Button{T'&Help', on_click=function()
      local help = assert(utils.path.module_path('samples.accessories.recently-visited-files', 'README.md'))
      mc.view(help)
    end}
  ))

  dlg:set_dimensions(nil, nil, tty.get_cols() - 6, tty.get_rows() - 8)

  ---------------------------- Keyboard handling -----------------------------

  local K = tty.keyname_to_keycode

  local forward_to_listbox = {
    [K'down'] = true,
    [K'up'] = true,
    [K'pgup'] = true,
    [K'pgdn'] = true,
  }

  local shortcuts = {
    [K'f4'] = 'edit',
    [K'f3'] = 'view',

    -- We can module-expose this table to let the user add,
    -- for example, the following to make ENTER follow the file.
    --[K'enter'] = 'goto',
  }

  dlg.on_key = function(self, kcode)
    if forward_to_listbox[kcode] then
      lst:_send_message(ui.MSG_KEY, kcode)
      return true
    end
    if shortcuts[kcode] then
      dlg.result = shortcuts[kcode]
      dlg:close()
      return true
    end
    return false
  end

  ----------------------------- Run and respond ------------------------------

  dlg.data = { is_recently_visited_dialog = true }

  local rslt = dlg:run()

  M.last_filter = fltr.text

  if lst.value then
    local rec = lst.value
    M.last_path = rec.path

    if rslt == 'edit' then
      if rec.edt then
        -- There's already an editbox with this file. Switch to it.
        --[[

          There seems to be a bug (or bugs) in MC in the mechanism that switches
          between modaless dialogs (around dialog-switch.c:dialog_switch_goto()).

          To see it, comment out everything except `rec.edt.dialog:focus()`. Then
          trigger this code several times to switch to such dialogs (by asking to
          edit already-opened files). Then try to switch to the filemanager. Even
          before you do that MC may crash.

          To "circumvent" this bug we don't switch directly to the editor but to
          the filemanager and *then* the editor (as can be seen in dialog_switch_goto(),
          these are different cases).

          A sure wy to see this big is to use mcedit (mc -e), where we can't
          switch to the filemanager. Therefore we disable this application on mcedit.

        ]]
        if ui.Panel.current then
          ui.Panel.current.dialog:focus()
        end
        timer.set_timeout(function()
          -- dialog:focus() doesn't return immediately: it starts an event loop.
          -- So timers started in code called from there (e.g., the blocks game)
          -- won't trigger unless we unlock the timer protection here.
          timer.unlock()
          rec.edt:focus()  -- There may be several editboxes in a single editor dialog.
          rec.edt.dialog:focus()
        end, 0)
      else
        mc.edit(rec.path)
      end
    elseif rslt == 'view' then
      mc.view(rec.path)
    elseif rslt == 'goto' then
      local dir, base = rec.path:match '(.*/)(.*)'
      ui.Panel.current.dir = dir
      ui.Panel.current.current = base
      ui.Panel.current.dialog:focus()  -- In case we're in the editor.
    end
  end

end

return M
