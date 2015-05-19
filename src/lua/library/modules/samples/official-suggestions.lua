--[[

This script enables most sample applications. To use it, put the
following in one of your startup scripts:

  require('samples.official-suggestions')

Alternatively, copy this file to your user Lua folder.

Some modules here are commented out. That's because not everybody may
like them, or because they may have some "side effect". Feel free to
uncomment them.

All modules have a comment at their top explaining their purpose and
how to enable them.

]]

-------------------------------- Filesystems ---------------------------------

require('samples.filesystems.mht')
require('samples.filesystems.sqlite')

local mysql = require('samples.filesystems.mysql')
-- You may want to uncomment and update the following:
--mysql.user = "bobby"
--mysql.password = "jhonson"  -- Leave 'nil' to have a dialog asking for it.

-------------------------------- Accessories ---------------------------------

ui.Listbox.bind('C-s', function()
  require('samples.accessories.find-as-you-type').run()
end)

-- Displays the GIT branch name at the bottom of the panel.
require('samples.accessories.git-branch')

-- Eye candy.
local shadow = require('samples.accessories.eyecandy.drop-shadow')
shadow.width = 4
shadow.height = 2
shadow.install()

-- "Recently visited files" dialog.
keymap.bind('M-pgup', function()
  require('samples.accessories.recently-visited-files').run()
end)

-- Ruler to measure lengths.
keymap.bind('M-r', function()
  require('samples.accessories.ruler').run()
end)

-- Save/restore the state of panels.
ui.Panel.bind('M-pgdn', function()
  require('samples.accessories.snapshots').run()
end)

-- Lets GNOME Terminal know of the current directory.
require('samples.accessories.set-gterm-cwd')

-- Displays scrollbars for panels.
require('samples.accessories.scrollbar').install()

-- Better xterm titles.
-- require('samples.accessories.set-xterm-title')  -- Disabled by default.

-- Displays a clock at the top-right corner.
--require('samples.accessories.clock').install()  -- Disabled by default.

-------------------------------- Screensaver ---------------------------------

-- After 3 minutes of keyboard inactivity:
--require('samples.screensavers.clocks.analog').install(3*60*1000)  -- Disabled by default.

----------------------------------- Games ------------------------------------

keymap.bind('C-x g b', function()
  require('samples.games.blocks').run()
end)

----------------------------------- Fields -----------------------------------

local gitf = require('samples.fields.git')
gitf.enabled = false  -- Start disabled.

ui.Panel.bind('C-f g e', function(pnl)
  gitf.enabled = true
  pnl:reload()
end)

ui.Panel.bind('C-f g d', function(pnl)
  gitf.enabled = false
  pnl:reload()
end)

require('samples.fields.better-size')
require('samples.fields.mplayer')
--require('samples.fields.bidi')  -- Disabled by default. Requires the 'bidiv' program.

------------------------------------ Apps ------------------------------------

keymap.bind('C-x c', function()
  require('samples.apps.calc').run()
end)

ui.Panel.bind('C-x r', function()
  require('samples.apps.visren').run()
end)
ui.Editbox.bind('C-x r', function()
  require('samples.apps.visren').run()
end)

------------------------ Quick filtering / panelizing ------------------------
--
-- MC doesn't provide a filter-as-you-type or panelize-as-you-type feature.
-- Don't worry: we provide two implementations for this:
--

--
-- Here we activate the filter-as-you-type feature with C-/, but
-- you may probably want to assign it to M-s (or C-s) instead.
--
ui.Panel.bind('C-_', function(pnl)
  require('samples.accessories.filter-as-you-type').run(pnl)
end)

--
-- The Visual Rename app can also function as a panelizer, as
-- it has a "Panelize" button.
--
-- We can make this panelizer even easier to use by providing
-- an `easy_panelize=true` flag, as shown here. This makes the
-- "Panelize" button the default one (that is, you just press
-- ENTER to apply), and it also means that you don't need to
-- mark files in advance.
--
ui.Panel.bind('C-p', function()
  require('samples.apps.visren').run{easy_panelize=true}
end)

--
-- Finally, you can easily undo the filter/panelization with C-r.
-- The marked files will remain marked.
--
ui.Panel.bind('C-r', require('samples.accessories.unfilter').run)

---------------------------------- Tickers -----------------------------------

-- Here's how to create a ticker (see the module for more details):

--[[

local ticker = require('samples.accessories.ticker')

ticker.new {
  command = "dmesg | tail -n 4",  -- The shell command whose output provides the data.
  lines = 4,                      -- Number of lines to display.
  interval = 30*1000,             -- (default.) Update every 30 seconds.
  region = 'north',               -- (default.) Or 'south'
}

]]

----------------------------------- Follow -----------------------------------

local function follow(...)
  require('samples.accessories.follow').follow(...)
end

ui.Panel.bind('C-x f', follow)

ui.Panel.bind('C-x C-f', function(pnl)
  follow(ui.Panel.other or pnl)
end)

-- Comment the following if you don't want 'enter' in panelized listings to follow.
ui.Panel.bind('enter', function(pnl)
  -- If we're not panelized, or there's something typed at the commandline, then skip.
  if (not pnl.panelized) or (ui.current_widget("Input") and ui.current_widget("Input").text ~= "") then
    return false
  end
  follow(pnl)
end)

---------------------------------- Editbox -----------------------------------

ui.Editbox.bind('C-x d', function()
  require('samples.editbox.dictionary').run()
end)

ui.Editbox.bind('C-x i', function()
  require('samples.editbox.unicodedata').run()
end)

ui.Editbox.bind('f12', function()
  require('samples.editbox.linter').run()
end)
ui.Editbox.bind('M-o', function(edt)
  edt:bookmark_flush()
end)

ui.Editbox.bind('C-\\', function()
  require('samples.editbox.funclist').run()
end)

ui.Editbox.bind('M-$', function(edt)
  require('samples.editbox.speller').check_word(edt)
end)
ui.Editbox.bind('M-!', function(edt)
  require('samples.editbox.speller').check_file(edt)
end)

-- Better file-locking for the editor.
require('samples.editbox.locking')

-- Displays a scrollbar in the editor.
--require('samples.editbox.scrollbar').install()  -- Disabled by default.

-- Displays a warning when user has no write access to file.
--require('samples.editbox.access-warning')  -- Disabled by default.

-- WordStar key-bindings.
--require('samples.editbox.wordstar')  -- Disabled by default.

-- "modeline" support.
--require('samples.editbox.modeline')  -- Disabled by default, because one usually has to provide a 'reset to defaults' function. Read its header for details.

---------------------------- Borrowings from Vim -----------------------------

-- Mimic vim's functionality of shift/unshift block:

ui.Editbox.bind('M-<', function(edt)
  if edt:get_markers() then
    edt:command "BlockShiftLeft"
  else
    -- Do the default action (of going to top of file).
    return false
  end
end)

ui.Editbox.bind('M->', function(edt)
  if edt:get_markers() then
    edt:command "BlockShiftRight"
  else
    -- Do the default action (of going to bottom of file).
    return false
  end
end)

-- When you're editing source code you sometimes wish to see
-- all the places on the screen where a variable is used.
--
-- In Vim this is done with the * (asterisk) key. Here we use
-- alt-* instead.
--
-- Press C-s twice to clear the highlight.
--
ui.Editbox.bind('M-*', function(edt)
  abortive(edt.current_word, T"Stand on a word, will you?")
  edt:add_keyword(edt.current_word, tty.style('editor.editbold'), nil, 'all')
  edt:redraw()
end)

------------------------------------ EOF -------------------------------------
