--[[

This program creates a few screenshots (in HTML format) demonstrating the
current skin.

This program is called by a shell script (generate.sh) which iterates
over all MC's skins.

See the README for info.

]]

---------------------------------- Imports -----------------------------------

local htmlize = require('samples.libs.htmlize')
local K = tty.keyname_to_keycode
local List = utils.table.new
local function file_exists(path) return fs.nonvfs_access(path, '') end

-- The 16-color palette to use. You may pick one of: tango, linux, xterm,
-- rxvt. Each assigns slightly different RGB values to the 16 colors.
htmlize.palette = htmlize.palettes.rxvt

---------------------- Output and mockup configuration -----------------------

local data_dir = fs.current_dir() .. '/mockup'
local output_prefix = os.getenv('MC_SKIN_SAMPLER_OUTPUT') or './skin'  -- Where to write the HTML.

local mockup = {

  left = {
    dir = '/etc',
    selected = 'X11',
  },

  right = {
    dir = data_dir .. '/demo-colors-dir',
    marked = { 'selected-file-1', 'selected-file-2' },
  },

  diff = {
    file1 = data_dir .. '/diff/file1.c',
    file2 = data_dir .. '/diff/file2.c',
  },

  viewer = {
    file = List {
      "/usr/share/man/man1/mc.1.gz",
      "/usr/share/man/man1/mc.1",
      "/usr/share/man/man1/bash.1.gz",
      "/usr/share/man/man1/bash.1",
      "/etc/fstab",
    }:filter(file_exists)[1],  -- Pick the 1st file found in this list.
  },

}

assert(file_exists(mockup.left.dir))
assert(file_exists(mockup.right.dir))
assert(file_exists(mockup.diff.file1))
assert(mockup.viewer.file, "I cannot find a file to view.")

----------------------------------- Utils ------------------------------------

local function get_main_dialog()
  return ui.Panel.current.dialog
end

local function take_shot(name)
  htmlize.htmlize_to_file(tty.get_canvas(), output_prefix .. '-' .. name .. '.html')
end

--------------------------------- Base setup ---------------------------------

-- Makes the panels show the desired folders.

local function setup_panels()
  local pnl_left, pnl_right = ui.Panel.left, ui.Panel.right

  pnl_left.dir = mockup.left.dir
  pnl_left.list_type = "full"
  pnl_left.current = mockup.left.selected
  if pnl_left.current == ".." then
    -- If the desired file to stand on is missing, at least move away from the ".."
    pnl_left:command "down"
  end
  pnl_left:focus()

  pnl_right.dir = mockup.right.dir
  pnl_right.marked = mockup.right.marked
  pnl_right.list_type = "full"
end

-------------------------------- "full" shot ---------------------------------

-- It shows the menu.

local function shoot_panel_full()

  local dlg = get_main_dialog()

  dlg:command "menu"
  local menu = dlg.current  -- The menu is now the current widget.

  -- The menu doesn't implement commands, so we send it keys.
  menu:_send_message(ui.MSG_KEY, K'l')  -- [L]eft
  menu:_send_message(ui.MSG_KEY, K'home')
  menu:_send_message(ui.MSG_KEY, K'down')
  menu:_send_message(ui.MSG_KEY, K'down')

  take_shot('panel-full')

  menu:_send_message(ui.MSG_KEY, K'esc')  -- Exit the menu.

end

-------------------------------- "brief" shot --------------------------------

-- It shows the "Copy" dialog.

local function shoot_panel_brief()
  local pnl_left, pnl_right = ui.Panel.left, ui.Panel.right
  pnl_left.list_type = "brief"
  get_main_dialog():command "copy"
end

-- When the "Copy" dialog comes up, we take a shot and close it.
ui.Dialog.bind('<<open>>', function(dlg)
  if dlg.text == T'Copy' then
    take_shot('panel-brief')
    -- There are two ways to close a dialog: either by doing dlg:command('cancel')
    -- or by doing dlg:close(). See explanation in `tests/nonauto/close_current_dialog.lua`
    -- to learn about the difference.
    dlg:command 'cancel'
  end
end)

-------------------------------- "long" shot ---------------------------------

-- It shows the "Delete" dialog.

local function shoot_panel_long()
  ui.Panel.current.list_type = "long"
  ui.Panel.current.dialog:command "delete"
end

ui.Dialog.bind('<<open>>', function(dlg)
  if dlg.text == T'Delete' then
    take_shot('panel-long')
    dlg:command 'cancel'
  end
end)

-------------------------------- Editor shot ---------------------------------

local function shoot_editor()

  ui.Editbox.options.show_numbers = true
  ui.Editbox.options.wrap_column = 72
  ui.Editbox.options.show_right_margin = true

  local filepath = assert(utils.path.module_path('samples.accessories.size-calculator'))
  mc.edit(filepath)

end

-- We could have put the following in <<Editbox::load>>, but because of
-- an MC glitch you can't call edt:command() in that event (reason explained
-- in the source). So we postpone this till <<Dialog::open>>.
--
local function setup_editbox(edt)

  -- Naturally, the "magic" numbers here we picked to look nice on this
  -- specific document. You'll want to update them if you use some other document.

  edt:bookmark_flush()
  edt:bookmark_set(53, tty.style("editor.bookmark"))
  edt:bookmark_set(65, tty.style("editor.bookmarkfound"))

  -- Mark a few lines.
  edt.cursor_line = 44  -- 39
  edt:command "home"
  edt:command "mark"
  edt:command "down"
  edt:command "down"
  edt:command "down"
  edt:command "mark"

  edt.cursor_line = 57
  edt.cursor_col = 40

end

-- When the editor comes up, we setup the document to our liking and call
-- the "complete word" dialog.
ui.Dialog.bind('<<open>>', function(dlg)
  if dlg:find 'Editbox' then  -- Is this the editor?
    local edt = dlg:find 'Editbox'
    setup_editbox(edt)
    edt:command 'complete'  -- opens the completion dialog.
    dlg:command 'cancel'
  end
end)

-- Take a shot and close the "complete word" dialog.
ui.Dialog.bind('<<open>>', function(dlg)
  -- A crude way to detect the completion dialog: it contains a solitary Listbox.
  if #dlg.mapped_children == 1 and dlg:find 'Listbox' and dlg.colorset == 'normal' then
    take_shot('editor')
    dlg:command 'cancel'
  end
end)

-------------------------------- Viewer shot ---------------------------------

local function shoot_viewer()
  mc.view(mockup.viewer.file)
end

ui.Dialog.bind('<<open>>', function(dlg)
  if dlg:find 'Viewer' then
    take_shot('viewer')
    -- The Viewer dialog doesn't respond to CK_Cancel, so `:command "cancel"` will have no effect. Instead we use `:close()`.
    dlg:close()
  end
end)

------------------------------ Diffviewer shot -------------------------------

local function shoot_diff()
  mc.diff(mockup.diff.file1, mockup.diff.file2)
end

ui.Dialog.bind('<<open>>', function(dlg)

  -- Detecting the Diffviewer dialog:
  --
  -- We can't do `dlg:find "Diffviewer"` because we haven't exposed this
  -- widget type to Lua (lack of interest). So instead we detect it with
  -- `dlg.current:command "HunkPrev"` as no other widget responds to this
  -- command.
  --
  -- @FIXME:
  -- Unfortunately, MC has a bug: WPanel reports all commands as having been
  -- handled (panel_execute_cmd() always returns MSG_HANDLED):
  --     http://www.midnight-commander.org/ticket/3547#comment:70
  -- Until this trivial bug gets fixed we add a check to exclude panels.

  local curr = dlg.current
  if curr:command "HunkPrev" and curr.widget_type ~= "Panel" then
    curr:command "ShowNumbers"
    curr:command "ShowSymbols"
    take_shot('diff')
    -- The Diffviewer dialog doesn't respond to CK_Cancel, so `:command "cancel"` will have no effect. Instead we use `:close()`.
    dlg:close()
  end

end)

------------------------------------------------------------------------------

local function take_shots()

  setup_panels()

  shoot_panel_full()
  shoot_panel_brief()
  shoot_panel_long()
  shoot_editor()
  shoot_viewer()
  shoot_diff()

end

---------------------------------- Running -----------------------------------

if os.getenv('MC_SKIN_SAMPLER_OUTPUT') then

  -- When this script is invoked form a shell script: do the job and exit.

  ui.queue(function()  -- Wait for the GUI.
    take_shots()
    os.exit()
  end)

else

  -- When somebody runs this script manually (when debugging): trigger the job with a keypress.

  ui.Panel.bind('C-q', function()
    take_shots()
  end)

end
