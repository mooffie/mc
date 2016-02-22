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
local List = utils.table.List

--
-- The 16-color palette to use. Some possibilities: tango, linux, xterm, rxvt,
-- putty, etc. Each assigns slightly different RGB values to the 16 colors.
--
htmlize.palette = htmlize.palettes.rxvt

--
-- Uncomment this to disable bold font (otherwise colors 8..15 are bold). Some
-- browsers do seem to have a problem with monospace bold font (see ticket #2147,
-- comment #11). But then make sure to pick a palette in which there's enough
-- contrast between gray (color 7) and white (color 15), or otherwise it'd be
-- hard to distinguish between them. The 'linux' palette (and not 'rxvt'!) would
-- be a good one.
--
--htmlize.bold_range = { min = -10, max = -10 }

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
    }:find(fs.file_exists),  -- Pick the 1st file found in this list.
  },

}

assert(fs.file_exists(mockup.left.dir))
assert(fs.file_exists(mockup.right.dir))
assert(fs.file_exists(mockup.diff.file1))
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
    -- There are two ways to close a dialog: either by doing
    -- dlg:command('cancel') or by doing dlg:close(). See note
    -- in dialog:close's documentation explaining the difference.
    --
    -- A rule of thumb: For dialogs that prompt for some kind of
    -- choice we use :command(). Other dialogs, usually full-screen,
    -- usually don't respond to CK_Cancel so for them we use :close().
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

  -- Naturally, the "magic" numbers here were picked to look nice on this
  -- specific document. You'll want to update them if you use some other document.

  edt:bookmark_flush()
  edt:bookmark_set(56, tty.style("editor.bookmark"))
  edt:bookmark_set(65, tty.style("editor.bookmarkfound"))

  -- Mark a few lines.
  edt.cursor_line = 47
  edt.cursor_col = 6
  edt:command "mark"
  edt.cursor_line = 49
  edt.cursor_col = 38
  edt:command "mark"

  -- Go to a position where we can show a nice "complete word" dialog.
  edt.cursor_line = 63
  edt.cursor_col = 38

  -- Scroll up a bit so the marked lines are visible.
  for _ = 1, 3 do
    edt:command "scrollup"
    edt:command "down"
  end

end

-- When the editor comes up, we setup the document to our liking and call
-- the "complete word" dialog.
ui.Dialog.bind('<<open>>', function(dlg)
  if dlg:find 'Editbox' then  -- Is this the editor?
    local edt = dlg:find 'Editbox'
    setup_editbox(edt)
    edt:command 'complete'  -- Open the completion dialog.
    dlg:close()
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
  -- Unfortunately, this is not quite true: an Editbox (WEdit, in C)
  -- reports all commands as having been handled (see MSG_ACTION case in
  -- edit_callback()), so we exclude it explicitly.

  local curr = dlg.current
  if curr:command "HunkPrev" and curr.widget_type ~= "Editbox" then
    curr:command "ShowNumbers"
    curr:command "ShowSymbols"
    take_shot('diff')
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
