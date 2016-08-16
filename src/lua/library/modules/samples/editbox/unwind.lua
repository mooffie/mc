--[[

UnWind: Makes it easier to work with text files from MS-Windows / DOS
---------------------------------------------------------------------

Features
--------

* Automatically/manually converts CR+LF (or CR alone) to LF.

* Provides a hotkey (C-w) for easily toggling "visible tabs" (as files
  coming from Visual Studio often use tabs).

* Displays an indicator at bottom-right corner.

Installation
------------

    require('samples.editbox.unwind').install()

(It's also possible to install only some of the features.)

Detailed explanation
--------------------

* Automatic Windows/DOS to Unix conversion:

  This automatic conversion, of CR characters, is done only under these
  conditions:

  - The file is small (< 200K).
  - It contains a CR char in 1st 1KB.
  - It doesn't look like a binary file (as we don't want to ruin image
    files, ELF, etc).

* Manual Windows/DOS to Unix conversion:

  This is done by hitting C-w. Use it when the file doesn't meet all the
  conditions needed for automatic conversion.

* Toggling "visible tabs":

  This is done by hitting C-w.

* Indicator:

  At the bottom-right corner an indicator shows you:

  - Whether the file was (automatically or manually) converted: "(cr-converted)".
  - Whether "visible tabs" is enabled: "T".
  - The tab size: "8", "4", etc.

]]

local M = {
  style = 'brightgreen, black; reverse',  -- the indicator style
  key = 'C-w',
  auto_conv_max_size = 1024*200,

  -- A callback that can be used to notify the user when the buffer gets
  -- automatically converted. You can override it to call tty.beep(), for example.
  on_auto_convert = function() end,
}

--------------------------------- Utilities ----------------------------------

--
-- This is a function similar in purpose to Emacs' save-excursion.
--
local function with_location(edt, fn)
  local line, col, top_line = edt.cursor_line, edt.cursor_col, edt.top_line
  local result = fn()
  -- @todo: switching the order of these two triggers a bug. Investigate!
  edt.cursor_line = line
  edt.cursor_col = col
  edt.top_line = top_line
  return result
end

--
-- Determines whether the file is textual (or binary).
--
-- We do this by seeing whether the first 1K is representable on the screen.
--
local function is_text(edt)
  local s = edt:sub(1, 1024)
  local screen = edt:to_tty(s)
  -- devel.view(tostring(s == screen) .. " "  .. s)
  return (s == screen)
end

------------------------------- CR Conversion --------------------------------

--
-- Does the actual conversion.
--
-- Returns 'true' if conversion was carried out.
--
local function convert_cr(edt)

  local mod = edt.modified
  local result = with_location(edt, function()
    local s = edt:sub(1)
    if not s:find "\r" then
      -- Don't waste undo memory.
      return false
    end
    edt.cursor_offs = 1
    edt:delete(s:len())
    edt:insert(s:gsub("\r\n?", "\n"))  -- This also deals with solitary CR (old Macs, '70s/'80s computers)
    return true
  end)
  edt.modified = mod

  return result

end

--
-- Convert. But run at most once.
--
local function convert_cr_once(edt)

  if edt.data.unwind_cr_converted then
    return
  end

  if convert_cr(edt) then
    edt.data.unwind_cr_converted = true
    edt:fixate()
  end

end

--
-- Convert. But only if the file meets some conditions:
--
-- * Small.
-- * Has CR at beginning.
-- * Isn't binary.
--
local function convert_cr_conditionally(edt)
  if edt:len() < M.auto_conv_max_size and edt:sub(1, 1024):find("\r") and is_text(edt) then
    convert_cr_once(edt)
    M.on_auto_convert(edt)
  end
end

-------------------------- Bindings / Installation ---------------------------

function M.install_auto_conv()
  ui.Editbox.bind('<<load>>', function(edt)
    convert_cr_conditionally(edt)
  end)
end

function M.install_indicator()
  local style
  ui.Editbox.bind('<<draw>>', function(edt)
    local s = (edt.data.unwind_cr_converted and "(cr-converted)" or "") ..
              (ui.Editbox.options.show_tabs and "T" or "") ..
              ui.Editbox.options.tab_size
    local c = edt:get_canvas()
    local border = edt.fullscreen and 0 or 1
    style = style or tty.style(M.style)  -- compile the style.
    c:set_style(style)
    c:goto_xy(c:get_cols() - s:len() - border, c:get_rows() - 1 - border)
    c:draw_string(s)
  end)
end

function M.install_key()
  ui.Editbox.bind(M.key, function(edt)
    convert_cr_once(edt)
    ui.Editbox.options.show_tabs = not ui.Editbox.options.show_tabs
  end)
end

function M.install()
  M.install_key()
  M.install_auto_conv()
  M.install_indicator()
end

------------------------------------------------------------------------------

return M
