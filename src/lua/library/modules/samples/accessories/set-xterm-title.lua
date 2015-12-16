--[[

Sets the terminal emulators's title (aka "xterm title") to something less
verbose, or to your own customized title.

This is useful because MC's default title is rather long, unfortunately making
the GUI obscure its important part(s).

Installation:

    require('samples.accessories.set-xterm-title')

And in case you want to customize the title:

    local ttl = require('samples.accessories.set-xterm-title')

    -- To somewhat mimic the default title:
    function ttl.generate_title(component, path)
      return ('mc [%s@%s]:%s'):format(
        os.getenv('USER') or '?',
        os.hostname(),
        ttl.longname(path)
      )
      -- Tip: `component` is "editor" when inside the editor.
    end

    -- You may also override ttl.lowlevel_set_title to govern
    -- how exactly to talk with your terminal (or it could be
    -- a Window Manager).

Another example:

    -- Here's how to append the process ID to the title.
    -- This is *very* useful sometimes when you have several MCs open; e.g.:
    -- * when you want to see which process locks some edited file;
    -- * when you want to kill a frozen program mc runs;
    -- * when you want to attach a debugger to a process, or send it SIGSTOP.

    local ttl = require('samples.accessories.set-xterm-title')

    local orig_title = ttl.generate_title
    function ttl.generate_title(...)
      return orig_title(...) .. " <" .. os.getpid() .. ">"
    end

Idea (loosely) taken from:

    http://www.midnight-commander.org/ticket/1364
    "overly verbose xterm window title"

]]

local M = {}

------------------------- Functions you may override -------------------------

--
-- The default title generator.
--
function M.generate_title(component, path)
  local ttl

  if component == 'editor' then
    ttl = '[E] ' .. M.basename(path)
  else
    ttl = '[M] ' .. M.longname(path)
  end

  return ttl
end

----------------------- Utilities for formatting paths -----------------------

local bor = utils.bit32.bor

function M.longname(path)
  return fs.VPath(path):to_str(bor(fs.VPF_STRIP_HOME, fs.VPF_STRIP_PASSWORD))
end

function M.basename(path)
  return path:match '.*/(.+)' or path
end

------------------------------------------------------------------------------

-- We make this a module-function so users can
-- override it.
function M.lowlevel_set_title(s)
  -- We use a timeout to defer this code till after MC writes out its own title.
  timer.set_timeout(function()
    io.stdout:write("\27]2;" .. s .. "\7")
    io.stdout:flush()
  end, 0)
end

local function set_title(component, path)
  devel.log('---- setting xterm title: ' .. component .. ', ' .. path)
  M.lowlevel_set_title(M.generate_title(component, path))
end

------------------------------------------------------------------------------

--
-- On switching to the editor.
--
local function on_edit(path)
  set_title('editor', path)
end

--
-- On switching to the panels (more correctly: to anything but the editor).
--
local function on_panel()
  local pnl = ui.Panel.current
  if pnl then
    set_title('filemanager', pnl.dir)
  end
end

--
-- Invoked when the user switches between windows.
--
local function on_window_switch(dlg)
  -- We could have done dlg:find('Editbox') as well, but current_widget('Editbox')
  -- is (negligibly) more efficient because it doesn't create Lua wrappers for all
  -- the widgets whithin.
  local edt = ui.current_widget('Editbox')
  if edt and edt.filename then
    on_edit(edt.filename)
  else
    on_panel()
  end
end

------------------ Detect changes in directory / component -------------------

local function install()

  ui.Dialog.bind('<<activate>>', on_window_switch)
  ui.Dialog.bind('<<open>>', on_window_switch)

  ui.Panel.bind('<<activate>>', on_panel)
  ui.Panel.bind('<<load>>', function(pnl)
    if pnl == ui.Panel.current then  -- Just to reduce excessive on_panel() calls. Not critical.
      on_panel()
    end
  end)

end

if os.getenv("DISPLAY") then
  install()
else
  devel.log(E"set-xterm-title.lua: It seems that you're not using a GUI terminal, which recognizes an ESC seq to change the title. I'm disabling myself.")
end

------------------------------------------------------------------------------

return M
