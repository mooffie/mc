--[[

This file contains high-level methods.

The low-level methods are implemented in C (they start with underscore). Here
we build, using Lua, a more high-level API, especially for marking files.

]]
--- @classmod ui.Panel

local ui = require("c.ui")

local append = table.insert

------------------------------------------------------------------------------
-- General methods.
-- @section panel-general

---
-- Iterates over the files displayed in the panel.
--
-- The values returned by the iterator are the ones described at
-- @{ui.Panel:current|current}.
--
--    ui.Panel.bind('C-y', function(pnl)
--      local count = 0
--
--      for fname, stat in pnl:files() do
--        if stat.type == "directory" and fname ~= ".." then
--          count = count + 1
--        end
--      end
--
--      alert(locale.format_plural(
--        "There is %d directory here",
--        "There are %d directories here",
--        count))
--    end)
--
-- @function files
function ui.Panel.meta:files(skip_stat)
  local i = 0
  return function()
    i = i + 1
    return self:_get_file_by_index(i, skip_stat)
  end
end

-- The following, undocumented, is a version that's easier to use in some places in this file.
function ui.Panel.meta:for_each(f, skip_stat)
  for i = 1, self:_get_max_index() do
    f(i, self:_get_file_by_index(i, skip_stat))
  end
end

-- Same, but in reverse:
function ui.Panel.meta:for_each_reversed(f, skip_stat)
  for i = self:_get_max_index(), 1, -1 do
    f(i, self:_get_file_by_index(i, skip_stat))
  end
end

---
-- Returns the current file.
--
-- That is, the file on which the "cursor" stands:
--
--    ui.Panel.bind("C-y", function(pnl)
--      alert(pnl.current)
--    end
--
-- Besides the filename, several more values are returned. You have to use
-- the method calling syntax -- `:get_current()` -- to access them:
--
--    -- Ask for confirmation before editing a huge file.
--    ui.Panel.bind("f4", function(pnl)
--      local filename, stat = pnl:get_current()
--      if stat.size < 5000000
--          or prompts.confirm(T"This file is huge. You really want to edit it?") then
--        return false  -- continue to the default action.
--      end
--    end)
--
-- @function current
-- @property rw
--
-- @return the filename
-- @return the @{fs.StatBuf|StatBuf}
-- @return boolean: whether the file is marked.
-- @return boolean: whether the file is the "current" one.
-- @return boolean: whether this is a broken symlink.
-- @return boolean: whether it's a directory whose size has been computed (this size is recorded in the StatBuf).
function ui.Panel.meta:get_current()
  return self:_get_file_by_index(self:_get_current_index())
end

function ui.Panel.meta:set_current(fname)
  for i = 1, self:_get_max_index() do
    if self:_get_file_by_index(i, true) == fname then
      self:_set_current_index(i)
      break
    end
  end
end

---
-- Filter files by a predicate function.
--
-- Only files for which the function returns **true** will remain. The
-- arguments the function receives are the ones described at
-- @{ui.Panel:current|current}.
--
--    -- Filter the display to only the marked files. (Press C-r to go
--    -- back to full view.)
--    --
--    -- (This is quite useful, as sometimes you wish to see which
--    -- files are marked without having to scroll in a giant list.)
--
--    ui.Panel.bind("M-f", function(pnl)
--      pnl:filter_by_fn(function(fname, stat, is_marked)
--        return is_marked
--      end)
--    end)
--
-- [info]
--
-- This filtering, in contrast to the one offered by the @{filter} property,
-- isn't persitent. Its effect vanishes once the panel is
-- reloaded (e.g., when the user returns to the panel from the editor).
--
-- You can remedy this by one of two means:
--
-- * Set the @{panelized} property to **true**. This will "fixate" your changes.
--
-- * You can create an illusion of persitance by attaching this filtering
--   to the @{load|<<load>>} event:
--
-- [indent]
--
--    -- Filter out zero-size files and *.pyc files, from
--    -- the home directory only.
--    ui.Panel.bind("<<load>>", function(pnl)
--      if pnl.dir == os.getenv("HOME") then
--        pnl:filter_by_fn(function(fname, stat)
--          return stat.size ~= 0 and not fname:find "%.pyc$"
--        end)
--      end
--    end)
--
-- [/indent]
--
-- [/info]
--
-- @function filter_by_fn
-- @args (fn)
function ui.Panel.meta:filter_by_fn(f, skip_stat)
  self:for_each_reversed(function(i, ...)
    if not f(...) then
      self:_remove(i)
    end
  end, skip_stat)
  self:redraw()
end

------------------------------------------------------------------------------
-- Marking and unmarking files
-- @section marking

---
-- Unmarks all the files.
-- @function clear
function ui.Panel.meta:clear()
  for i = 1, self:_get_max_index() do
    self:_mark_file_by_index(i, false)
  end
  self:redraw()
end

-------------------------------- By function ---------------------------------

---
-- Marks files by a predicate function.
--
-- Mark all files satisfying some condition. Receives as an argument a
-- function that's to return **true** if a file is to be marked. The
-- arguments the function receives are the ones described at
-- @{ui.Panel:current|current}.
--
--    ui.Panel.bind("C-x plus s", function(pnl)
--      local min_size_s = prompts.input(T'Mark all files bigger than: (enter, for example, "200K", "50M", ...)')
--      if min_size_s then
--        local min_size = abortive(utils.text.parse_size(min_size_s))
--        pnl:mark_by_fn(function(fname, stat)
--          return stat.size >= min_size
--        end)
--      end
--    end)
--
-- @function mark_by_fn
-- @args (fn)
function ui.Panel.meta:mark_by_fn(f, skip_stat)
  self:for_each(function(i, a, b, is_marked, ...)
    if not is_marked and f(a, b, is_marked, ...) then
      self:_mark_file_by_index(i, true)
    end
  end, skip_stat)
  self:redraw()
end

---
-- Unmarks files by a predicate function.
--
-- See @{mark_by_fn}.
--
-- @function unmark_by_fn
-- @args (fn)
function ui.Panel.meta:unmark_by_fn(f, skip_stat)
  self:for_each(function(i, a, b, is_marked, ...)
    if is_marked and f(a, b, is_marked, ...) then
      self:_mark_file_by_index(i, false)
    end
  end, skip_stat)
  self:redraw()
end

---------------------------------- By name -----------------------------------

---
-- Marks files by name.
--
-- Marks all the files given as the **list** parameter.
--
-- Note: Previously marked files remain marked. If you wish to unmark them,
-- call @{clear} before calling this method.
--
--    pnl:clear()
--    pnl:mark({"Makefile", "hook.c"})
--
--    -- Add all the files marked on the other panel:
--    pnl:mark(ui.Panel.other.marked)
--
--    -- And the selected file:
--    pnl:mark(pnl.current)
--
-- See another example in @{git:mark_files_by_contents.lua}.
--
-- @function mark
-- @param list A table of file names. Can also be a string. Can also be **nil** (in which case it's a no-op).
function ui.Panel.meta:mark(...)
  return self:mark_or_unmark(true, ...)
end

---
-- Unmarks files by name.
--
-- Unmarks all the files given as the **list** parameter.
--
-- See further details at @{mark}.
--
-- @function unmark
-- @args (list)
function ui.Panel.meta:unmark(...)
  return self:mark_or_unmark(false, ...)
end

function ui.Panel.meta:mark_or_unmark(positive, list)

  if type(list) == "nil" then
    -- We support nil so that we can unconditionally do `saved = pnl.marked; ... ; pnl.marked = saved`
    list = {}
  elseif type(list) == "string" then
    list = { list }
  end
  assert(type(list) == "table", E"The files to mark must be a table")

  local set = require("utils.table").makeset(list)

  self[positive and "mark_by_fn" or "unmark_by_fn"](self, function(fname)
    return set[fname]
  end, true)

  self:redraw()
end

---
-- Returns a table of the marked files.
--
-- If no files are marked, returns **nil**; this makes it easier to provide
-- a default value using "or":
--
--    local files_to_operate_on = pnl.marked or { pnl.current }
--
-- This property is writable, which simply makes it an alternative to @{clear}+@{mark}:
--
--    -- Mark all web pages saved from Wikipedia.
--
--    ui.Panel.bind('C-y', function(pnl)
--      pnl.marked = prompts.please_wait(T"Locating files",
--        function()
--          return fs.tglob('*.mht', {conditions={
--            function(path) return fs.read(path, 1024):find('Content-Location: http://en.wikipedia.org', 1, true) end
--          }})
--        end
--      )
--    end)
--
-- (A variation of the code above is available as
-- @{git:mark_files_by_contents.lua}.)
--
-- @attr marked
-- @property rw

function ui.Panel.meta:get_marked()
  local marked = {}

  for file, _, is_marked in self:files(true) do
    if is_marked then
      append(marked, file)
    end
  end

  return next(marked) and marked
end

function ui.Panel.meta:set_marked(list)
  self:clear()
  self:mark(list)
end

---------------------------------- By glob -----------------------------------

---
-- Marks files by glob pattern.
--
--    pnl:glob("*.c")
--
-- Tip: You can also do `pnl:mark(fs.tglob("*.c"))`, but this, contrary to the
-- above, would involve disk access. See example at @{marked} for an
-- interesting use of @{fs.tglob}.
--
-- @function glob
-- @args (pattern)
function ui.Panel.meta:glob(...)
  return self:glob_or_unglob(true, ...)
end

---
-- Unmarks files by glob pattern.
-- @function unglob
-- @args (pattern)
function ui.Panel.meta:unglob(...)
  return self:glob_or_unglob(false, ...)
end

function ui.Panel.meta:glob_or_unglob(positive, gpat, opts)

  opts = opts or {}

  assert(type(gpat) == "string", E"The pattern must be a string")

  local re = require("utils.glob").compile(gpat, opts.nocase and "i")

  self[positive and "mark_by_fn" or "unmark_by_fn"](self, function(fname)
    return fname:p_match(re)
  end, true)

  self:redraw()

end

------------------------------------------------------------------------------

ui._setup_widget_class("Panel")
