--[[

Snapshots -- save/restore the state of panels.

Installation:

    ui.Panel.bind('M-pgdn', function()
      require('samples.accessories.snapshots').run()
    end)

See the help file (README.md).

]]

local core = require('samples.accessories.snapshots.core')

local M = {
  -- How many columns to allocate for a snapshot's name in the listing:
  name_width = 12,
}

------------------------------------------------------------------------------

--
-- Like tty.keyname_to_keycode except that it doesn't throw an exception.
-- Returns 'nil' on error.
--
local function keyname_to_keycode(keyname)
  local ok, kcode = pcall(tty.keyname_to_keycode, keyname)
  return ok and kcode or nil  -- "or nil" is because we need to return 'nil', not 'false'.
end

-- Extract the key in "my snapshot [C-s]".
local function extract_key(shot_name)
  local keyname = shot_name:match '%[(.-)%]'
  if keyname then
    return keyname_to_keycode(keyname), keyname
  end
end

function M.take_shot()

  local dlg = ui.Dialog(T"Take a snapshot")

  local name = ui.Input{expandx=true}

  local which_opts = {
    ui.Panel.left and ui.Panel.right and {'&Both', value='both'} or false,
    ui.Panel.left and {'&Left', value='left'} or false,
    ui.Panel.right and {'&Right', value='right'} or false,
  }
  which_opts = utils.table.filter(which_opts, function(v) return v end)

  local which = ui.Radios{items=which_opts}

  local domain = ui.Radios{items={
    {'&Everything (sort, listing mode, ...)', value='everything'},
    {'&Directory only', value='dir'},
  }}

  dlg:add(
    ui.Groupbox(T"Snapshot name"):add(
      name,
      ui.Label("You may embed a key name in brackets, like [p],\n[M-p], [C-p], or [f2], for quick access.")
    ),
    ui.Groupbox(T"Which panel to save?"):add(which),
    ui.Groupbox(T"Which settings to save?"):add(domain)
  )

  dlg:add(ui.DefaultButtons())

  local function validate_key(shot_name)
    local keycode, keyname = extract_key(name.text)
    if keyname and not keycode then
      alert(T'Invalid keyname "%s"':format(keyname), T"Warning")
    end
  end

  if dlg:run() then
    local shot = core.take_shot(which.value, domain.value)
    validate_key(name.text)
    shot.name = name.text
    core.add_shot(shot)
  end

end

------------------------ Rendering a snapshot's title ------------------------

local strip_home_flag = utils.bit32.bor(fs.VPF_STRIP_HOME, fs.VPF_STRIP_PASSWORD)

local function short_path(path, max)
  if not path then
    return T'<none>'
  end
  local s = fs.VPath(path):to_str(strip_home_flag)
  local ellipsis = tty.is_utf8() and '…' or '...'
  if s:len() > max then
    s = ellipsis .. tty.text_align(s, max - tty.text_width(ellipsis), 'right')
  end
  return s
end

local function graphics(s)
  return s:gsub('|', tty.skin_get('Lines.vert', '|'))
end

--
-- Render the title, while trying to keep it under 'width' columns.
--
local function format_title(shot, width)

  local fmt = graphics("%3s | %3s | %s |%s| ")

  local s = fmt:format(
    utils.text.format_interval_tiny(os.time() - shot.date),
    os.date("%Y-%m-%d %H:%M", shot.date),
    tty.text_align(shot.name, M.name_width, 'left'),
    core.has_dir_only(shot) and ' ' or '+'
  )

  local room_left = math.max(width - tty.text_width(s), 20)

  if shot.single then
    local max = room_left - 1
    s = s .. short_path(shot.single.dir, max)
  else
    local max = math.floor((room_left - 3) / 2)
    s = s .. short_path(shot.left.dir, max) .. ", " .. short_path(shot.right.dir, max)
  end

  return s

end

------------------------------------------------------------------------------

local function restore_shot_part(shot)

  local dlg = ui.Dialog(T"Restore part")

  local which = ui.Radios{items={
    {'&Both', value='both'},
    {'&Left', value='left'},
    {'&Right', value='right'}
  }}

  local domain = ui.Radios{items={
    {'&Everything (sort, listing mode, ...)', value='everything'},
    {'&Directory only', value='dir'},
  }}

  dlg:add(
    ui.Label(T"Pick the data you wish restored out of the snapshot."),
    ui.ZLine()
  )

  if not shot.single then
    dlg:add(
      ui.Groupbox(T"Which panel to restore?"):add(
        which,
        ui.HLine(),
        ui.Label(T'Note: if you restore just one panel, it will be\nrestored into the current panel.')
      )
    )
  end

  dlg:add(ui.Groupbox(T"Which settings to restore?"):add(
    core.has_dir_only(shot) and ui.Label(T"(This shot has only a directory stored in it.)") or domain
  ))

  dlg:add(ui.DefaultButtons())

  if dlg:run() then
    core.restore_shot(shot, which.value, domain.value)
  end

end

------------------------------------------------------------------------------

--
-- The main dialog.
--

function M.run()

  core.reload()  -- In case the DB on disk was edited directly by the user, or altered by some other MC process.

  local dlg = ui.Dialog{T"Snapshots", padding=0}

  local lst = ui.Listbox{expandy=true}

  local function populate_listbox()
    local width = lst.cols - 2
    lst.items = core.map(function (shot)
      return {
        format_title(shot, width),
        value = shot,
        hotkey = extract_key(shot.name)
      }
    end)
  end

  function dlg.on_init()  -- We have to wait till on_init() for lst.cols to reflect the layout.
    populate_listbox()
  end

  local function delete()
    if lst.value then
      local pos = lst.selected_index
      core.delete_shot(pos)
      populate_listbox()
      lst.selected_index = math.min(pos, #lst.items)
    end
  end

  dlg:add(
    lst,
    ui.Buttons():add(
      ui.Button{T"&Restore", type='default', result="restore"},
      ui.Button{T"Restore &part", result="restore part"},
      ui.Button{T"&Add", result="add"},
      ui.Button{T"De&lete", on_click=delete}
    ),
    ui.Buttons(true):add(
      ui.Button{T"Ra&w", result="raw"},
      ui.Button{T'&Help', on_click=function()
        local help = assert(utils.path.module_path('samples.accessories.snapshots', 'README.md'))
        mc.view(help)
      end},
      ui.CancelButton()
    )
  )

  dlg:set_dimensions(nil, nil, tty.get_cols() - 18, math.max(tty.get_rows() - 14, 14))

  local rslt = dlg:run()

  if rslt == "add" then
    M.take_shot()
  elseif rslt == "raw" then
    mc.edit(core.get_path())
  else
    local shot = lst.value
    if shot then
      if rslt == "restore" or rslt == true then  -- 'true' when a snapshot hotkey is pressed.
        core.restore_shot(shot)
      elseif rslt == "restore part" then
        restore_shot_part(shot)
      end
    end
  end

  core.unload()  -- Not really needed. Can conserve some memory, though negligible.

end

------------------------------------------------------------------------------

return M
