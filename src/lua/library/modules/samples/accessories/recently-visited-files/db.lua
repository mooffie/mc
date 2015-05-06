--[[

Provides the database for the "Recently visited files" dialog.

]]

local append = table.insert

local M = {}

--------------------------------- DB sources ---------------------------------

--
-- The database has three sources:
--
--  * The currently edited files.
--  * The locked files (edited elsewhere).
--  * The 'filepos' entries.
--

local function foreach_edited_file(callback)
  for _, dlg in ipairs(ui.Dialog.screens) do
    -- There may be several editboxes in a single editor dialog.
    for edt in dlg:gmatch('Editbox', function(e) return e.filename end) do
      callback(edt)
    end
  end
end

local function foreach_lock(callback)
  local locker = require('samples.libs.locking-impl')
  for _, rec in ipairs(locker.get_locks()) do
    callback(rec)
  end
end

local function filepos_exists()
  return fs.stat(conf.path('filepos')) ~= nil
end

local function foreach_filepos_entry(callback)
  if not filepos_exists() then
    return
  end
  for ln in io.lines(conf.path('filepos')) do
    local path, data = ln:match '(.*) (.*)'
    if path then
      callback(path)
    end
  end
end

------------------------------ Building the DB -------------------------------

--[[

The database is a table compatible with the Listbox:items format. Each record has
a 'value' key for the data itself, and a [1] key for the visual representation of it:

  {
    {
      "* ~/path/to/file.txt,
      value = {
        path = "/home/joe/path/to/file.txt",
        edt = <Editbox>
      }
    },
    {
      "! /another/file.txt,
      value = {
        path = "/another/file.txt",
        lock = { ... }
      }
    },
    {
      "  /some/other/file,
      value = {
        path = "/some/other/file",
      }
    },
    ...
  }

]]

-- The user can override this. See explanation in README.md.
function M.alter_db()
end

local render  -- fwd declaration.

--
-- Builds the DB! It merges all the sources.
--
function M.build()

  local db = {}

  local seen = {}

  foreach_edited_file(function(edt)
    seen[edt.filename] = true
    append(db, { value = { path = edt.filename, edt = edt }})
  end)

  foreach_lock(function(lock)
    if not seen[lock.resource_name] then
      seen[lock.resource_name] = true
      -- We keep the whole lock (instead of just doing 'locked = true') so
      -- that the alter_db hook can look into it, if it wants to.
      append(db, { value = { path = lock.resource_name, lock = lock } })
    end
  end)

  foreach_filepos_entry(function(path)
    if not seen[path] then
      append(db, { value = { path = path } })
    end
  end)

  render(db)

  M.alter_db(db)

  return utils.table.new(db)

end

local strip_home_flag = utils.bit32.bor(fs.VPF_STRIP_HOME, fs.VPF_STRIP_PASSWORD)

--
-- Builds the visual representation of each record. That is, what the
-- listbox will show.
--
function render(db)
  for _, rec in ipairs(db) do
    rec[1] = ( (rec.value.edt  and '*') or
               (rec.value.lock and '!') or
                                   ' '     )
               -- We can append 'rec.value.path' directly, of course, but let's
               -- strip the homedir. Maybe somebody could benchmark this to see
               -- what's the performance penalty, if there's any.
               .. ' ' .. fs.VPath(rec.value.path):to_str(strip_home_flag)
  end
end

---------------------------------- Deleting ----------------------------------

local function filepos_delete(path_to_delete)
  if not filepos_exists() then
    return
  end
  local tmpf, tmp_path = fs.temporary_file()
  for ln in io.lines(conf.path('filepos')) do
    local path, data = ln:match '(.*) (.*)'
    if path ~= path_to_delete then
      assert(tmpf:write(ln, "\n"))
    end
  end
  assert(tmpf:close())
  mc.mv(tmp_path, conf.path('filepos'))
end

function M.delete_record(db, path)
  filepos_delete(path)
  return db:filter(function(rec) return rec.value.path ~= path end)
end

------------------------------------------------------------------------------

return M
