--[[

Browse MySQL databases as if they were files.

Installation:

    require('samples.filesystems.mysql')

or:

    local mysql = require('samples.filesystems.mysql')
    mysql.user = "bobby"
    mysql.password = "jhonson"  -- leave 'nil' to have a dialog asking for it.

Usage:

Type "cd mysql://" inside MC and enjoy!

]]

--[[

It'd be interesting to compare this script with a FUSE/Ruby one:

  http://www.debian-administration.org/article/619/Creating_Filesystems_with_Ruby__and_FUSE

]]

local append = table.insert

local M = {}

M.user = nil
M.password = nil

--
-- We're passing the user/password via "option file"; see:
--
--   http://dev.mysql.com/doc/refman/5.0/en/password-security-user.html
--
-- The "--defaults-extra-file" is supported on 4.0 also:
--

local commands = {
  [".dump.sql"] = "mysqldump --defaults-extra-file=!option_file --skip-extended-insert !db !table",
  [".sql"]      = "mysqldump --defaults-extra-file=!option_file --compact --no-create-info --skip-extended-insert !db !table",
  [".xml"]      = "mysqldump --defaults-extra-file=!option_file --xml !db !table",

  [".tsv"]      = "mysql --defaults-extra-file=!option_file !db --raw --silent -e 'SELECT * FROM !table' ",
  [".txt"]      = "mysql --defaults-extra-file=!option_file !db --vertical --silent --raw -e 'SELECT * FROM !table' ",
  [".ascii"]    = "mysql --defaults-extra-file=!option_file !db --table -e 'SELECT * FROM !table' ",
  [".html"]     = "mysql --defaults-extra-file=!option_file !db --html -e 'SELECT * FROM !table' | sed -e 's,<TR,\\n<TR,g' -e 's,</TABLE>,\\n\\0\\n,' ",

  check = "mysql --defaults-extra-file=!option_file < /dev/null 2>&1 && echo success"
}

local function build_command(session, cmd_t, args)
  args = args or {}
  return (cmd_t:gsub('!([%w_]+)', function (token)
    local replacement = session[token] or args[token] or error(("missing token '%s'"):format(token))
    return replacement
  end))
end

local function run_command(session, cmd_t, args)
  local f = io.popen(build_command(session, cmd_t, args))
  local output = f:read("*a")
  f:close()
  return output
end

local function list_dbs(session)
  return run_command(session, "mysql --defaults-extra-file=!option_file --silent -e 'show databases' "):l_tsplit()
end

local function list_tables(session, db)
  return run_command(session, "mysql --defaults-extra-file=!option_file !db --silent -e 'show tables' ", { db = db }):l_tsplit()
end

-- Breaks "drupal/node.sql" into { db = "drupal", table = "node", exttension = ".sql" }
local function parse_request(path)
  local db, table, extension = path:match "^([^/]+)/?([^.]*)(.*)"
  return {
    db = db,
    table = (table ~= "" and table),
    extension = (extension ~= "" and extension),
  }
end

local mysqlfs = {

  prefix = "mysql",

  readdir = function(session, path)

    local request = parse_request(path)

    -- Root directory: show all DBs.
    if not request.db then
      return list_dbs(session)
    end

    -- A subfolder: show the tables in that DB.
    local files = {}
    for _, table in ipairs(list_tables(session, request.db)) do
      for extension, _ in pairs(commands) do
        if extension:find '^%.' then
          append(files, table .. extension)
        end
      end
    end

    return files
  end,

  stat = function(session, path)
    if path:find '/' then
      return { type = "regular" }
    else
      return { type = "directory" }
    end
  end,

  file = function(session, path, mode, info)

    local request = parse_request(path)

    if mode ~= "r" then
      return   -- LuaFS will translate that into EROFS ("Read-only file system")
    end

    assert(commands[request.extension], E"Unrecognized file extension")

    local f, tempname = fs.temporary_file {prefix="mysql"}

    local cmd = build_command(session, commands[request.extension] .. " > !tempname", {
      db = request.db,
      table = request.table,
      tempname = tempname
    })
    os.execute(cmd)

    fs.unlink(tempname)

   return f

  end,

  is_same_session = function(...)
    return true
  end,

  -- How we appear on the "Active VFSs" dialog.
  get_name = function(...)
    -- The starting "/" is not crucial. The advantage is that if the user
    -- then navigates, from the "Active VFSs" dialog, to this directory and
    -- then bookmarks it, it will be this absolute URL and not something
    -- that's prepended by the current directory.
    return "/mysql://"
  end,

  open_session = function(session)
    abortive(require("samples.libs.os").try_program("mysql --version"), E"The program 'mysql' isn't installed.")

    -- @FIXME: MC won't parse user/password embedded in URLs for LuaFS filesystems.
    -- That's because LuaFS doesn't have the VFS_S_REMOTE flag. See comment in fs.VPath.
    --
    -- Maybe we should expose C's vfs_url_split(). This provides easy access
    -- to user/password embedded in URLs.

    local user = M.user or os.getenv("USER") or "root"
    local password = M.password or prompts.get_password(T'MySQL connection for user "%s"':format(user)) or ""
    local optf
    optf, session.option_file = fs.temporary_file{prefix="mysqlopts"}
    optf:write("[client]\n")
    optf:write("user=" .. user .. "\n")
    optf:write("password=" .. password .. "\n")
    optf:close()
    devel.log("optfile is " .. session.option_file)

    local message = run_command(session, commands.check)
    if not message:find "success" then
      abort(message)  -- Inform user about bad user/password etc.
    end

  end,

  close_session = function(session)
    fs.unlink(session.option_file)
  end

}

function M.install()
  fs.register_filesystem(mysqlfs)
end

M.install()

return M
