--[[

Browse SQLite3 databases as if they were files.

Installation:

    require('samples.filesystems.sqlite')

Usage:

- Stand on a *.sqlite (or *.sq3) file and press ENTER.

- Or type "cd whatever.the.file.name/sqlite://".

- Or add the following to your extension file:

    type/^SQLite 3.x database
      Open=%cd %p/sqlite://

]]

local append = table.insert

local M = {}

local function cmd(cmd, ...)
  local f = io.popen(cmd:format(...))
  local output = f:read("*a")
  f:close()
  return output
end

local commands = {
  [".schema.sql"] = "sqlite3 %q '.schema %s'",
  [".sql"] = "sqlite3 %q '.dump %s'",
  [".csv"] = "sqlite3 -csv %q 'SELECT * FROM %s'",
  [".tsv"] = "sqlite3 -separator '\t' %q 'SELECT * FROM %s'",
  [".txt"] = "sqlite3 -line %q 'SELECT * FROM %s'",
  [".html"] = "sqlite3 -html %q 'SELECT * FROM %s'",
}

local sqlitefs = {

  prefix = "sqlite",

  -- @FIXME: We should instead use "type='^SQLite 3.x database'" once we support it.
  iglob = '*.{sq3,sqlite}',

  readdir = function(session, p)
    local files = {}
    for _, table in ipairs(session.tables) do
      for extension, i in pairs(commands) do
        append(files, table .. extension)
      end
    end
    return files
  end,

  file = function(session, path, mode, info)

    local table, flavor = path:match "([^.]*)(.*)"  -- Break "table.sql" into ("table, ".sql")

    if mode ~= "r" then
      return   -- LuaFS will translate that into EROFS ("Read-only file system")
    end

    assert(commands[flavor], E"Unrecognized file extension")

    local f, tempname = fs.temporary_file {prefix="sqlite"}
    os.execute((commands[flavor] .. " > %q"):format(session.db_name, table, tempname))
    fs.unlink(tempname)
    return f

  end,

  open_session = function(session)
    abortive(require("samples.libs.os").try_program("sqlite3 -version"), E"The program 'sqlite3' isn't installed.")
    session.db_name = session.parent_path.str
    session.tables = utils.text.tsplit(cmd("sqlite3 %q .tables", session.db_name), '%s+')
  end,

}

function M.install()
  fs.register_filesystem(sqlitefs)
end

M.install()

return M
