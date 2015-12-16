---
-- @module luafs

--[[

Adds support for pressing ENTER in panels.

IMPORTANT:

This is a convenience feature only. This script is not an integral part
of LuaFS. LuaFS itself knows nothing, and needs to know absolutely
NOTHING, about panels or the UI portion of MC.

]]

--- Panel-integration properties.
--
-- These properties determine whether pressing ENTER on a file will cause MC
-- to `cd` into it.
--
-- For example, when given the following filesystem,
--
--    local MarkdownFS = {
--      prefix = "markdown",
--      glob = "*.md",
--      ...
--    }
--
-- then standing over the file "cheats.md" and pressing ENTER will `cd` you
-- to "cheats.md/markdown://".
--
-- [info]
--
-- This is a convenience feature only. You can always `cd` "by hand" (or
-- by instructing MC to do so in your _extension file_).
--
-- [/info]
--
-- @section luafs-panel

--- Determine @{~#panel|panel integration} by Perl-compatible regex.
--
-- See example at @{iregex}.
--
-- @attr regex
-- @args

--- Determine @{~#panel|panel integration} by case-insensitive Perl-compatible regex.
--
-- Example:
--
--    local MarkdownFS = {
--      prefix = "markdown",
--      iregex = [[\.(md|mkd|mdown)$]],
--      ...
--    }
--
-- @attr iregex
-- @args

--- Determine @{~#panel|panel integration} by a glob pattern.
--
-- See example at @{iglob}.
--
-- @attr glob
-- @args

--- Determine @{~#panel|panel integration} by case-insensitive glob pattern.
--
-- Example:
--
--    local MarkdownFS = {
--      prefix = "markdown",
--      iglob = "*.{md,mkd,mdown}",
--      ...
--    }
--
-- @attr iglob
-- @args


local fs_iterator = require('luafs')._fs_iterator
local fnmatch = require('fs').fnmatch

local implementation = {

  on_panel_enter = function(fs, pnl, basename)

    if fs.iregex and regex.match(basename, {fs.iregex, 'i'}) then
      return true
    end
    if fs.regex and regex.match(basename, fs.regex) then
      return true
    end
    if fs.iglob and fnmatch(fs.iglob, basename, {nocase=true}) then
      return true
    end
    if fs.glob and fnmatch(fs.glob, basename) then
      return true
    end

    -- @FIXME: We should support type= and itype= too, but currently MC too
    -- runs 'file', and doesn't cache it, so we'd end us calling it twice.
  end,

}

ui.Panel.bind('enter', function(pnl)

  local basename, stat, _, _, is_broken = pnl:get_current()

  if stat.type == 'directory' or is_broken then
    return false
  end

  if ui.current_widget("Input") and ui.current_widget("Input").text ~= "" then
    -- There's a command typed on the commandline. Skip.
    return false
  end

  for _, fs in fs_iterator() do
    if fs.on_panel_enter(fs, pnl, basename) then
      pnl.dir = basename .. '/' .. fs.prefix .. '://'
      return
    end
  end

  return false

end)

local function install(fs)

  -- We let the user override 'on_panel_enter' in his filesystem to enable
  -- him to do more complicated stuff, like looking at the type of the file
  -- as reported by /usr/bin/file.
  if not fs.on_panel_enter then
    fs.on_panel_enter = implementation.on_panel_enter
  end

end

return {
  install = install,
}
