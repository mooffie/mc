--[[

This module contains the non-UI stuff of snapshots.

The UI is in 'init.lua'.

]]

local List = utils.table.List

local M = {
  --
  -- Where to store the shots.
  --
  -- (This typically ends up in ~/.local/share/mc/snapshots.)
  --
  dir = conf.dirs.user_data .. '/snapshots',
}

local shots_path = M.dir .. '/snapshots.lua'

-- Settings to save.
local fields = {
  -- Note: The order is important. See comment in set_panel_settings().
  'dir', 'sort_field', 'sort_reverse', 'list_type', 'num_brief_cols',
  'custom_format', 'custom_mini_status', 'custom_mini_status_format',
  -- Properties implemented by us. See below.
  'snapshot_panelized_list', 'snapshot_panelized_command',
  -- 'current' comes after panelization because the file possibly isn't in
  -- the list prior to that.
  'current',
}

-- The database!
local shots = {
}

function M.iterate()
  return utils.table.iterate(shots)
end

function M.map(fn)
  return utils.table.map(shots, fn)
end

function M.get_path()
  return shots_path
end

local header = [[
--
-- This file stores your snapshots.
--
-- Feel free to edit it to tweak your snapshots. For example, you may
-- remove settings you don't want restored. But make sure not to alter
-- the overall structure of this file, of course.
--
-- Don't bother with comments and formatting: these will be removed as
-- the file gets rewritten.
--
]]
local function save_shots()
  local temp_path = fs.temporary_string_file(header, "return ", devel.pp(shots), "\n")
  assert(fs.rename(temp_path, shots_path))
end

local function load_shots()
  if fs.file_exists(shots_path) then
    shots = dofile(shots_path)
  else
    -- Just so that the "Raw" button can bring up a file. No other reason.
    save_shots()
  end
end

function M.reload()
  load_shots()
end

function M.unload()
  shots = nil
end

function M.delete_shot(idx)
  table.remove(shots, idx)
  save_shots()
end

local function get_panel_settings(pnl, domain)
  if domain == 'dir' then
    return {
      dir = pnl.dir
    }
  else
    local settings = {}
    for _, name in ipairs(fields) do
      settings[name] = pnl[name]
    end
    return settings
  end
end

local function set_panel_settings(pnl, settings, domain)

  if settings.dir then
    -- Tell user of directories that no longer exist, etc.
    local ok, errmsg = fs.nonvfs_access(settings.dir, 'x')
    if not ok then
      alert(errmsg)
    end
  end

  if domain == 'dir' then
    if settings.dir then  -- The user may have edited this out.
      pnl.dir = settings.dir
    end
  else
    -- Note: the order in which we set the fields is important: We can't set
    -- 'current' before 'dir', or 'custom_mini_status_format' before 'list_type'.
    for _, name in ipairs(fields) do
      if settings[name] ~= nil then  -- The user may have edited some settings out.
        pnl[name] = settings[name]
      end
    end
  end

end

function M.take_shot(which, domain)
  local shot = {
    date = os.time()
  }
  if which == 'both' then
    shot.left = get_panel_settings(ui.Panel.left, domain)
    shot.right = get_panel_settings(ui.Panel.right, domain)
  else
    shot.single = get_panel_settings(ui.Panel[which], domain)
  end
  return shot
end

function M.add_shot(shot)
  table.insert(shots, 1, shot)
  save_shots()
end

function M.restore_shot(shot, which, domain)

  if which and which ~= "both" then
    set_panel_settings(ui.Panel.current, shot[which], domain)
  else
    if shot.left and ui.Panel.left then
      set_panel_settings(ui.Panel.left, shot.left, domain)
    end
    if shot.right and ui.Panel.right then
      set_panel_settings(ui.Panel.right, shot.right, domain)
    end
    if shot.single then
      set_panel_settings(ui.Panel.current, shot.single, domain)
    end
  end

end

--------------------- Panel properties implemented by us ---------------------
--
-- We define two properties, "snapshot_panelized_{list,command}", to make
-- it possible to store/load panelized panels.
--

function ui.Panel.meta:set_snapshot_panelized_list(list)
  if list then
    assert(type(list) == "table", E"You can only assign a table to the 'snapshot_panelized_list' property.")  -- In case the use mis-edits the DB.
    self:panelize_by_list(list)
  end
end

function ui.Panel.meta:get_snapshot_panelized_list()
  if self.panelized then
    return List(self:files()):sub(2):unmeta()
  end
end

function ui.Panel.meta:set_snapshot_panelized_command(cmd)
  if cmd then
    assert(type(cmd) == "string", E"You can only assign a string to the 'snapshot_panelized_command' property.")  -- In case the use mis-edits the DB.
    self:panelize_by_command(cmd)
  end
end

-- This property is write-only, but we still need to provide a 'getter'
-- because Snapshots will try to read it.
function ui.Panel.meta:get_snapshot_panelized_command()
  return nil
end

----------------------------------- Setup ------------------------------------

local function setup()
  -- Create the snaps directory, if not exists.
  if not fs.file_exists(M.dir) then
    assert(fs.nonvfs_mkdir_p(M.dir))
  end
end

------------------------------------------------------------------------------

setup()

return M
