--- Lets users write filesystems in Lua.
--
-- Please see the @{~filesystems|user guide} for explanation on creating
-- filesystems.
--
-- Note: This document describes not functions you can call but functions
-- your filesystem objects should implement.
--
-- Info-short: This document uses the terms "functions", "operations" and
-- "operators" interchangeably.
--
--## Signaling errors
--
-- An operator may signal an error by returning a **pair** or a **triad**:
-- first a nil, then an Operating System's error code (either in the second
-- or third place; this "fuzziness" is for compatibility with the standard
-- Lua OS functions, which by convention return a triad).
--
-- You can get by, however, by just returning nothing (or a nil): an
-- appropriate error code will be deduced for you.
--
-- For example, if a @{stat} operator returns nothing, it's as if a
-- ENOENT pair ("No such file or directory") was returned:
--
--    function MyFS:stat(pathname)
--      if pathname == "one.txt" then
--        return { type="regular", size=1000 }
--      elseif pathname == "extra" then
--        return { type="directory" }
--      end
--      -- implicitly return (nil, ENOENT) for any other pathanme.
--    end
--
-- As another example, an implementation of a @{git:luafs_mirror.lua|mirror filesystem}
-- that just forwards calls to another one is trivial: due to the way Lua's
-- "return" preserves multiple values (the triads, in our case), the errors
-- are propagated, as desired, without special effort on our part.
--
-- @pseudo
-- @module luafs

assert(require("conf").features.luafs, E"Support for LuaFS hasn't been compiled in.")

--[[

# Implementation

The LuaFS component is written almost entirely in Lua. A small portion
is written in C (see 'src/vfs/luafs/luafs.c'). The C portion is just a
layer that forwards everything to the Lua side.

The Lua side registers several functions (about two dozen) with the C
side (see 'entry_points' towards the end of this Lua file). This is
how the C side knows where to forward calls.

# Demultiplexing

LuaFS is basically a demultiplexer: MC asks it to carry out some
operation on a path (e.g., delete a file) or a filehandle (e.g., read
from a file) and LuaFS channels the request to the filesystem
responsible for this path/filehandle. LuaFS does little besides
that.

That's the meaning of the "demux_" you see in the names of all the entry
points (which the C side calls).

# Sessions

The only abstraction LuaFS provides is the concept of a session. You can
think of filesystems as 'types' and of sessions as the actual 'objects'.

]]

---------------------------------------- Imports -----------------------------------------

local bor, band = import_from('utils.bit32', { 'bor', 'band' })
local register_system_callback, is_restarting = import_from('internal', { 'register_system_callback', 'is_restarting' })
local append = table.insert

-- Functions that manage VFS's GC mechanism. See usage explained in 'lib/vfs/gc.c'.
local stamp, rmstamp, stamp_create = import_from('luafs.gc', { 'stamp', 'rmstamp', 'stamp_create' } )

-- The following lets us search this file for "errors." for example to see all
-- errors we use. It serves no other purpose.
local const, errors = require('fs'), require('fs')

----------------------------------- Module variables -------------------------------------

local fsdb = {}        -- Holds all registered filesystems, keyed by their prefix.
local sessions = {}    -- Holds all open sessions, keyed by their numeric ID.

local sess_id_counter = 1  -- Used for generating IDs for sessions.

-- Returns a filesystem for managing a certain path.
local function get_fs(vpath)
  return fsdb[ vpath:last().vfs_prefix:lower() ]
end

---------------------------------- Utility functions -------------------------------------

local function DBG(...)
  --return print('[LUAFS]', ...)
end

-- Returns 'true' if a table is empty (or nil).
local function empty(tbl)
  return not (tbl and next(tbl))
end

local function show_stamps()
  devel.view(require('luafs.gc').get_vfs_stamps())
end

---------------------------------- Creating a session ------------------------------------

--- Properties.
-- @section luafs-fields

--- The filesystem's ID, or "URL scheme".
--
-- The `prefix` property, when embedded in a path, identifies the path (whole
-- or part of it) as belonging to a certain filesystem.
--
-- for example, given a filesystem that handles ZIP files,
--
--    ZipFS = {
--      prefix = "zip",
--      ...
--    }
--
-- then typing a path like `/home/john/book.7z/zip://text/chapter1.txt` will
-- access the file `text/chapter1.txt` within the ZIP archive `book.7z`.
--
-- Tip: For filesystems that represent archives, the `prefix` doesn't have to
-- equal the archive's suffix. We could just as well have chosen the prefix
-- "doodle" for our ZipFS filesystem.
--
-- As another example, given a filesystem that displays your MySQL databases,
--
--    MysqlFS = {
--      prefix = "mysql",
--      ...
--    }
--
-- then doing `cd mysql://` will navigate to a directory listing the databases.
--
-- @attr prefix
-- @args

---
-- @section end


--- Initializes a session.
--
-- See discussion in the @{~filesystems#Sessions|user guide}
-- and at @{is_same_session}.
--
-- You're free to modify the session object, but make sure not to touch
-- the few internal variables already stored there. Among the variables
-- already there:
--
-- - **parent_path**: points to the path containing
--   our session. E.g., when accessing `"/outer/path/myfs://inner/path"`,
--   `parent_path` is `"/outer/path"`.
--
-- Tip: You're allowed to throw an exception from @{open_session}. For
-- example, you may want to do that if an external program you're dependent
-- on isn't installed. See examples in @{git:mysql.lua} and @{git:sqlite.lua}.
--
-- @attr open_session
-- @param session


local function create_new_session(fs, initiating_path)

  local session = {
    parent_path = initiating_path:parent(),

    -- The following could be useful for keeping around the user/password
    -- details. But, unfortunately, MC doesn't currently parse these
    -- details for LuaFS filesystems (see note in fs.VPath's ldoc). So
    -- we don't document this field yet.
    initiating_path = initiating_path,

    id = sess_id_counter,
    time_opened = os.time(),
    open_files = {},
    fs = fs,
  }

  if fs.open_session then
    fs.open_session(session)
  end

  -- Note: We register the session *after* calling open_session because
  -- open_session my elect to fail, by raising exception.

  sessions[session.id] = session
  sess_id_counter = sess_id_counter + 1

  -- Tell VFS's GC mechanism to GC us in a minute. Don't worry:
  -- if the user interacts with us further, this will be postponed.
  stamp_create(session.id)

--  show_stamps()
  return session
end


--- Determines whether a path belongs to this session.
--
-- When a path is accessed, every session is asked whether this path is under
-- its control. The first session that answer **true** is used to serve the
-- request. If the path belongs to no session, a new session is created (see
-- @{open_session}).
--
-- If this operator isn't implemented, the following default implementation
-- will take place:
--
--    function FileSystem:is_same_session(vpath)
--       return self.parent_path.str == vpath:parent().str
--    end
--
-- (This default logic favors archive-style filesystems and is
-- @{~filesystems#archives|explained in the user guide}. For non-archives,
-- simply @{~filesystems#non-archive|make this operator return 'true'}.)
--
-- @attr is_same_session
-- @param session
-- @param vpath The path to test. (A @{fs.VPath} is used, instead of a
--   string, for easier access to parsed elements such as username and
--   password.)


-- Given a path, return the FS describing it. Returns also a session:
-- either an already opened session the path belongs to, or a new session.
local function get_fs_and_session(vpath, do_not_open)
  local fs = get_fs(vpath)

  if not fs and is_restarting() then
     alert(E[[
You're trying to access a filesystem, "%s", whose code hasn't been
loaded yet. This could happen if you have, for example, code that
triggers panel:reload() in a startup script, and this before you
require() the filesystem. You'll now see a traceback that shows where
the offending call originates in your startup script.]]:format(vpath:last().vfs_prefix), E"Lua Restart")
  end

  for _, sess in pairs(sessions) do
    if sess.fs == fs then
      if fs.is_same_session(sess, vpath) then
        -- Tell VFS's GC mechanism to postpone our GC.
        stamp(sess.id)
        return fs, sess
      end
    end
  end

  if do_not_open then
    return fs
  else
    return fs, create_new_session(fs, vpath)
  end

  -- @todo:
  --
  -- This function does about the same thing the C function
  -- vfs_get_super_by_vpath() does.
  --
  -- Interestingly, the C function (see tar_super_same(), in tar.c) allows
  -- archives to "reload" themselves, if the archives's mtime has changed on
  -- disk. We should have a similar functionality and enable it by default.

end

--------------------------------- Destroying a session -----------------------------------

--- Cleans up after a session.
--
-- You may use this operator to delete temporary files you created or close a socket.
--
-- See discussion in the @{~filesystems#open sessions|user guide}.
--
-- @attr close_session
-- @param session

local function demux_free(session_id)
  local session = sessions[session_id]
  if session then
    if session.fs.close_session then
      session.fs.close_session(session)
    end
    sessions[session_id] = nil
  end
end

----------------------------- Dispatching helper functions -------------------------------

local function select_error(a, b, default_errcode)
  if type(a) == "number" then
    return a
  elseif type(b) == "number" then
    return b
  else
    return default_errcode
  end
end

local function handle_simple_result(default_errcode, f, ...)
  if f then
    local value, a, b = f(...)
    if value then
      return value
    else
      return nil, select_error(a, b, default_errcode)
    end
  else
    -- This file system doesn't support this operation.
    return nil, errors.E_NOTSUPP
  end
end

----------------------------------- Demultiplexing ---------------------------------------

--- Opens a file.
--
-- This function should return some "file handle", which is *whatever* Lua
-- value you wish it to be. MC donesn't look inside this value: it's passed
-- as-is to the other operators (@{read}, @{write}, @{seek}, @{close}).
--
-- If the function returns nothing, it's as if the the triad `ENOENT` ("No
-- such file or directory"), when reading, or `EROFS` ("Read-only file
-- system"), when writing, was returned.
--
-- The argument this operator gets:
--
-- - **session** - The session.
--
-- - **pathname** - The pathname of the file.
--
-- - **mode** - Open mode. One of: "r", "w", "a", "r+", "w+", "a+". (This
--   is the approximated translation of `info.posix_flags` (see next).)
--
-- - **info** - A table with:
--
--     - posix_flags - The open mode given in numeric code. A bitwise-or of
--       `O_RDONLY`, `O_WRONLY`, `O_RDWR`, etc.
--     - creation_mode - When creating a file, the permission bits to use.
--     - mc_flags - The same as posix_flags, except that it may include the
--       MC-specific flag `O_LINEAR`.
--
-- @attr open
-- @args (session, pathname, mode, info)

-- Note to C programmers, about names of arguments/variables:
--
-- open(2) uses "mode" to refer to the creation permission
-- bits; fopen(3) uses "mode" for the "r"/"w"/"r+" string. We use
-- the fopen semantics.

local posix_to_ansi -- "forward declaration"

local function demux_open(vpath, mc_flags, creation_mode, posix_flags)
  DBG("MUX_open()", vpath:tail())
  local fs, session = get_fs_and_session(vpath)
  local path = vpath:tail()

  if fs.open then

    local info = {
      posix_flags = posix_flags,
      mc_flags = mc_flags,
      creation_mode = creation_mode,
    }
    local ansi_mode = posix_to_ansi(mc_flags)
    local fh, a, b = fs.open(session, path, ansi_mode, info)

    if fh then
      -- Once we have at least 1 opened files, we tell VFS's GC mechanism
      -- to stop tracking us.
      rmstamp(session.id)

      local file_node = {
        fh = fh,

        -- Since we won't be able to figure out the filesystem/session from the filehandle (fh) alone (since we don't have the prefix, which is in the vpath),
        -- we store the session as well.
        session = session,

        -- Nevertheless, we store the path too so we can improvise fstat() for filesystems that don't implement it.
        path = path
      }
      session.open_files[file_node] = true
      return file_node
    else
      return nil, select_error(a, b, ansi_mode == "r" and errors.ENOENT or errors.EROFS)
    end

  else
    -- This file system doesn't support opening files.
    return nil, errors.E_NOTSUPP     -- "Function not implemented"
  end
end

local modes = {

  { id = "a+", bits = bor(const.O_RDWR,   const.O_APPEND) },
  { id = "a",  bits = bor(const.O_WRONLY, const.O_APPEND) },

  { id = "w+", bits = bor(const.O_RDWR,   const.O_TRUNC) },
  { id = "w+", bits = bor(const.O_RDWR,   const.O_CREAT) },
  { id = "w",  bits = const.O_WRONLY },

  { id = "r+", bits = const.O_RDWR },
  { id = "r" , bits = const.O_RDONLY },

}

-- Converts numeric POSIX flags to *approximated* ANSI strings.
-- E.g., a mode containing O_RDWR and O_CREAT is converted to "w+".
function posix_to_ansi(flags)
  for _, mode in ipairs(modes) do
    if band(flags, mode.bits) == mode.bits then
      return mode.id
    end
  end
  -- We shouldn't arrive here because 'flags' ought to contain O_RDONLY,
  -- O_WRONLY, or O_RDWR, which we cover.
  error(E"Invalid POSIX open mode %d.":format(flags))
end

--- Writes to a file.
--
-- To signal success, the function should return some *truth* value. It
-- may return the number of bytes written (if it doesn't, this number will
-- be assumed to be the written strings' length.)
--
-- If the function returns nothing, it's as if an EIO triad was returned ("Input/output error").
--
-- If the function is not implemented, it's as if an EROFS triad was returned ("Read-only file system").
--
-- @attr write
-- @param session
-- @param filehandle Whatever @{open} previously returned.
-- @param buf The string to write.

local function demux_write(file_node, buf)
  DBG("MUX_write()", buf)
  local fs = file_node.session.fs

  if fs.write then
    local written, a, b = fs.write(file_node.session, file_node.fh, buf)
    if not written then
      return nil, select_error(a, b, errors.EIO)
    else
      -- Success.
      -- We're to return the number of bytes written. If we get a non-number, we improvise
      -- the number as being the buffer size.
      return (type(written) == "number") and written or buf:len()
    end
  else
    return nil, errors.EROFS
  end
end

--- Reads from a file.
--
-- Must return a triad on error.
--
-- On success, the string read should be returned. On EOF, the function may
-- return either an empty string or nothing (therefore a triad must be
-- returned on real error).
--
-- If the function is not implemented, it's as if an E_NOTSUPP triad was
-- returned ("Function not implemented").
--
-- @attr read
-- @param session
-- @param filehandle Whatever @{open} previously returned.
-- @param count The number of bytes to read.

local function demux_read(file_node, count)
  DBG("MUX_read()", count)
  local fs = file_node.session.fs

  if fs.read then
    local s, a, b = fs.read(file_node.session, file_node.fh, count)
    if not s and (a or b) then
      -- Read error.
      return nil, select_error(a, b, errors.EIO)
    else
      -- success
      return s
    end
  else
    -- This file system doesn't support reading.
    return nil, errors.E_NOTSUPP
  end
end

--- Seeks in a file.
--
-- @attr seek
-- @param session
-- @param filehandle Whatever @{open} previously returned.
-- @param whence  One of "set", "cur", "end".
-- @param offs A number.

local function demux_seek(file_node, whence, offs)
  DBG('MUX_seek()', whence, offs)
  local session = file_node.session

  if whence == const.SEEK_CUR then
    whence = "cur"
  elseif whence == const.SEEK_END then
    whence = "end"
  else
    whence = "set"
  end

  return handle_simple_result(errors.E_NOTSUPP, session.fs.seek, session, file_node.fh, whence, offs)
end

--- Closes a file.
--
-- To signal success, the function should return some *truth* value.
-- Remember to do this, because, although many programmers neglect to check
-- the return value of close(), proper code does, and if you don't signal
-- success the code will fail.
--
-- If the function returns nothing, it's as if an EIO triad was returned
-- ("Input/output error").
--
-- @attr close
-- @param session
-- @param filehandle Whatever @{open} previously returned.

local function demux_close(file_node)
  DBG("MUX_close()")
  local session = file_node.session

  session.open_files[file_node] = nil

  if empty(session.open_files) then
    -- We went from 1 open file to 0 open files.
    -- Tell VFS's GC mechanism to resume tracking us.
    stamp_create(session.id)
  end

  return handle_simple_result(errors.EIO, session.fs.close, session, file_node.fh)
end

--- Returns a directory's contents.
--
-- Returns a list of all files in a directory.
--
-- Each entry is a string, which is the filename (the basename only; don't use
-- slashes). Or an entry may be a list whose first element is a string and the
-- second a number denoting the inode.
--
-- If the function returns nothing, it's as if an ENOENT triad was
-- returned ("No such file or directory").
--
--    function MyFS:readdir(dir)
--      if dir == "" then  -- the top directory.
--        return {"one.txt","two.txt","three.txt"}
--      end
--    end
--
-- By default, each file is considered a regular file having zero size.
-- If you want to override this, implement @{stat}.
--
-- If the function is not implemented, it's as if the filesystem
-- contains an empty top directory.
--
-- @attr readdir
-- @param session
-- @param dir The directory. The top directory is "" (an empty string).

local function demux_opendir(vpath)
  DBG('MUX_opendir()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  local path = vpath:tail()

  if fs.readdir then
    local list, a, b = fs.readdir(session, path)
    if not list then
      return nil, select_error(a, b, errors.ENOENT)
    elseif type(list) ~= "table" then
      error(E"The '%s' filesystem's file() operation must return either a table or nothing; but %s was returned.":format(
        session.fs.prefix, type(list)))
    else
      return {
        contents = list,
        pos = 1,
      }
    end
  else
    -- We shouldn't arrive here, as we provide a default implementation (see defaults.readdir).
    return nil, errors.E_NOTSUPP
  end
end

local function demux_readdir(pkg)
  DBG('MUX_readdir()', pkg)

  -- 'pkg' is the structure demux_opendir() returned.
  if pkg.contents[pkg.pos] then
    local row = pkg.contents[pkg.pos]
    pkg.pos = pkg.pos + 1
    if type(row) == "table" then
      -- If an inode exists, return it.
      return row[1], row[2]
    else
      -- Else, improvise inode.
      return row, 100 + pkg.pos
    end
  end

  -- Implicitly return nil, signaling we've reached end of dir.
end

local function demux_closedir(pkg)
  DBG('MUX_closedir()', pkg)
  return true
end

--- Returns stat information about a file.
--
-- Optional. If you don't implement this, all files will be regarded a
-- regular files having zero size.
--
-- Returns either a @{fs.StatBuf} or a table to be passed to its @{~mod:fs*StatBuf|constructor}.
-- As a convenience, if you provide a table, the timestamps, if missing, will
-- be initialized to the time the session was opened.
--
-- If the function returns nothing, it's as if an ENOENT triad was returned
-- ("No such file or directory").
--
-- If the function is not implemented, every pathname queried will be reported
-- as existing (and being a regular file of zero size).
--
--    function MyFS:stat(pathname)
--      if pathname == "one.txt" or pathname == "two.txt" then
--        return { size = 1000 }
--      elseif pathname == "three" then
--        return { type = "directory" }
--      else
--    end
--
-- @attr stat
-- @param session
-- @param pathname The pathname to the file (or directory).

local function fixup_statbuf(session, sttbf)
  if type(sttbf) == "table" then  -- possibly convert a table into sttbf...
    if not sttbf.mtime then  -- add defaults...
      sttbf.mtime = session.time_opened
      sttbf.atime = session.time_opened
      sttbf.ctime = session.time_opened
    end
    return fs.StatBuf(sttbf)
  elseif type(sttbf) == "userdata" then
    return sttbf
  else
    error(E"The '%s' filesystem's stat/lstat/fstat() operation must return either a fs.StatBuf or a table; but %s was returned.":format(
      session.fs.prefix, type(sttbf)))
  end
end

local function do_stat(session, f, path)
  if f then
    local sttbf, a, b = f(session, path)
    if not sttbf then
      return nil, select_error(a, b, errors.ENOENT)
    else
      return fixup_statbuf(session, sttbf)
    end
  else
    -- We shouldn't arrive here, as we provide a default implementation (see defaults.stat).
    return nil, errors.E_NOTSUPP
  end
end

local function demux_stat(vpath)
  DBG('MUX_stat()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  return do_stat(session, fs.stat, vpath:tail())
end

--- Returns stat information about a file.
--
-- Like @{stat} but doesn't dereference symbolic links.
--
-- If not implemented, the @{stat} function will be used instead.
--
-- @attr lstat
-- @param session
-- @param pathname The pathname to the file (or directory).

local function demux_lstat(vpath)
  DBG('MUX_lstat()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  return do_stat(session, fs.lstat or fs.stat, vpath:tail())     -- we fall back on stat()
end

local function demux_fstat(file_node)
  DBG('MUX_fstat()', file_node.fh)
  local fs, session = file_node.session.fs, file_node.session

  if fs.fstat then
    local sttbf, a, b = fs.fstat(session, file_node.fh)
    if not sttbf then
      return nil, select_error(a, b, errors.EBADF)
    else
      return fixup_statbuf(session, sttbf)
    end
  else
    -- This file system doesn't support fstat. Improvise it by calling
    -- stat() on the path.
    return do_stat(session, fs.stat, file_node.path)
  end
end

--- Renames a file.
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned
-- ("Function not implemented").
--
-- @attr rename
-- @param session
-- @param path1 Source.
-- @param path2 Destination.
local function demux_rename(vpath1, vpath2)
  DBG('MUX_rename()', vpath1:tail(), vpath2:tail())

  local fs, session = get_fs_and_session(vpath1)
  return handle_simple_result(errors.E_NOTSUPP, fs.rename, session, vpath1:tail(), vpath2:tail())
end

--- Creates a hard link.
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned
-- ("Function not implemented").
--
-- See also @{symlink}.
--
-- @attr link
-- @param session
-- @param path1 Source.
-- @param path2 Destination.
local function demux_link(vpath1, vpath2)
  DBG('MUX_link()', vpath1:tail(), vpath2:tail())

  local fs, session = get_fs_and_session(vpath1)
  return handle_simple_result(errors.E_NOTSUPP, fs.link, session, vpath1:tail(), vpath2:tail())
end

--- Creates a symbolic link.
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned
-- ("Function not implemented").
--
-- @attr symlink
-- @param session
-- @param path1 Source.
-- @param path2 Destination.
local function demux_symlink(vpath1, vpath2)
  DBG('MUX_symlink()', vpath1:tail(), vpath2:tail())

  local fs, session = get_fs_and_session(vpath2) -- The second (destination) path determines the FS.
  return handle_simple_result(errors.E_NOTSUPP, fs.symlink, session, vpath1.str, vpath2:tail())
end

--- Deletes a file.
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned ("Function not implemented").
--
-- @attr unlink
-- @param session
-- @param path
local function demux_unlink(vpath)
  DBG('MUX_unlink()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  return handle_simple_result(errors.E_NOTSUPP, fs.unlink, session, vpath:tail())
end

--- Creates a directory.
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned ("Function not implemented").
--
-- @attr mkdir
-- @param session
-- @param path
local function demux_mkdir(vpath)
  DBG('MUX_mkdir()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  return handle_simple_result(errors.E_NOTSUPP, fs.mkdir, session, vpath:tail())
end

--- Deletes a directory.
--
-- (This is a low-level function; The directory must be empty.)
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned ("Function not implemented").
--
-- @attr rmdir
-- @param session
-- @param path
local function demux_rmdir(vpath)
  DBG('MUX_rmdir()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  return handle_simple_result(errors.E_NOTSUPP, fs.rmdir, session, vpath:tail())
end

--- Changes the permission bits of a file.
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned ("Function not implemented").
--
-- @attr chmod
-- @param session
-- @param path
-- @param mode
local function demux_chmod(vpath, mode)
  DBG('MUX_chmod()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  return handle_simple_result(errors.E_NOTSUPP, fs.chmod, session, vpath:tail(), mode)
end

--- Changes the ownership of a file.
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned ("Function not implemented").
--
-- @attr chown
-- @param session
-- @param path
-- @param owner
-- @param group
local function demux_chown(vpath, owner, group)
  DBG('MUX_chown()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  return handle_simple_result(errors.E_NOTSUPP, fs.chown, session, vpath:tail(), owner, group)
end

--- Creates a special (or ordinary) file.
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned ("Function not implemented").
--
-- @attr mknod
-- @param session
-- @param path
-- @param mode
-- @param dev
local function demux_mknod(vpath, mode, dev)
  DBG('MUX_mknod()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  return handle_simple_result(errors.E_NOTSUPP, fs.mknod, session, vpath:tail(), mode, dev)
end

--- Changes file last access and modification times.
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned ("Function not implemented").
--
-- @attr utime
-- @param session
-- @param path
-- @param modtime
-- @param actime
local function demux_utime(vpath, modtime, actime)
  DBG('MUX_utime()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  return handle_simple_result(errors.E_NOTSUPP, fs.utime, session, vpath:tail(), modtime, actime)
end

--- Reads the contents of a symbolic links.
--
-- If not implemented, it's as if an E_NOTSUPP triad was returned ("Function not implemented").
--
-- @attr readlink
-- @param session
-- @param path
local function demux_readlink(vpath)
  DBG('MUX_readlink()', vpath:tail())

  local fs, session = get_fs_and_session(vpath)
  return handle_simple_result(errors.E_NOTSUPP, fs.readlink, session, vpath:tail())
end

--- Enters a directory.
--
-- If not implemented, **true** (meaning: success) is returned.
--
-- If nothing is returned it's as if an EACCES triad was returned ("Permission denied").
--
-- @attr chdir
-- @param session
-- @param path
local function demux_chdir(vpath)
  local fs, session = get_fs_and_session(vpath)
  return handle_simple_result(errors.EACCES, fs.chdir, session, vpath:tail())
end

--- Flushes a directory index.
--
-- When you reload a panel (e.g. by pressing C-r) this operation is invoked. You
-- may use it to invalidate a cached directory index.
--
-- @attr flush
-- @param session
-- @param path The directory to flush, for granular control. You may of course ignore this and flush your whole cache.

--- Runs a program.
--
-- Invoked when you press ENTER over an executable. If not implemented,
-- nothing then happens.
--
-- @attr run
-- @param session
-- @param path

local function demux_setctl(vpath, op, arg)
  if op == "flush" or op == "run" or op == "forget" or op == "stale_data" then
    -- Note: if you ever implement "logfile", don't call
    -- get_fs_and_session(): this will create a phantom session, as logfile
    -- operates on a whole filesystem, not on a specific session. Call
    -- get_fs() instead.
    devel.log(devel.pp{vpath:extract(),op,arg})
    local fs, session = get_fs_and_session(vpath)
    if fs[op] then
      return fs[op](session, vpath:tail(), arg)
    end
  end
  return false
end

------------------------------ Interface with the C side ---------------------------------

local entry_points = {

  ["luafs::open"] = demux_open,
  ["luafs::read"] = demux_read,
  ["luafs::close"] = demux_close,
  ["luafs::seek"] = demux_seek,
  ["luafs::write"] = demux_write,
  ["luafs::opendir"] = demux_opendir,
  ["luafs::readdir"] = demux_readdir,
  ["luafs::closedir"] = demux_closedir,
  ["luafs::stat"] = demux_stat,
  ["luafs::lstat"] = demux_lstat,
  ["luafs::fstat"] = demux_fstat,
  ["luafs::rename"] = demux_rename,
  ["luafs::unlink"] = demux_unlink,
  ["luafs::rmdir"] = demux_rmdir,
  ["luafs::mkdir"] = demux_mkdir,
  ["luafs::link"] = demux_link,
  ["luafs::chmod"] = demux_chmod,
  ["luafs::chown"] = demux_chown,
  ["luafs::readlink"] = demux_readlink,
  ["luafs::utime"] = demux_utime,
  ["luafs::chdir"] = demux_chdir,
  ["luafs::symlink"] = demux_symlink,
  ["luafs::mknod"] = demux_mknod,
  ["luafs::free"] = demux_free,
  ["luafs::setctl"] = demux_setctl,

  -- Returns 'true' if a path (a prefix, to be exact) can be handled by us.
  ["luafs::which"] = function (prefix)
    DBG('which()', prefix)
    return fsdb[prefix:lower()]
  end,

  --- Returns a path representing the session.
  --
  -- This path is shown in the "Active VFS" dialog of MC.
  --
  -- @attr get_name
  -- @args (session)

  ["luafs::fill_names"] = function ()
    local names = {}
    for _, session in pairs(sessions) do
      --append(names, "[sid " .. session.id .. "] " .. session.parent_path.str)
      append(names, session.fs.get_name(session))
    end
    return names
  end,

  -- Returns the ID of a session. This ID is something MC's VFS component can pass around.
  ["luafs::getid"] = function (vpath)
    local _, session = get_fs_and_session(vpath, true)
    return session and session.id
  end,

  -- Tells MC whether a session has no open files (and therefore can be freed).
  ["luafs::nothingisopen"] = function (session_id)
    local session = sessions[session_id]
    return session and empty(session.open_files)
  end,
}

for slot, func in pairs(entry_points) do
  register_system_callback(slot, func)
end

------------------------- Filesystem validation and registration -------------------------

--
-- default implementations for certain operators.
--
local defaults = {

  -- This simple test is appropriate for archive filesystems. Non-archive filesystems
  -- (like mysql://drupal6/tables/user) would want to override it.
  is_same_session = function(session, vpath)
    -- Maybe we should define VPath:parent_str() in C?
    return session.parent_path.str == vpath:parent().str
  end,

  get_name = function(session)
    return session.parent_path.str .. "/" .. session.fs.prefix .. "://"
  end,

  -- A file is by default a regular file, having zero size. Any file exists.
  stat = function()
    return {}
  end,

  -- The filesystem contains a single, top-level empty directory.
  readdir = function(session, dir)
    if dir == "" then
      return {}
    end
  end,

  chdir = function()
    return true
  end,
}

local function validate_fs(fs)

  assert(type(fs.prefix) == "string", E"Filesystem must have a string 'prefix' property.")

  if fs.open and not fs.close then
    error(E"Filesystem implements open() but doesn't implement close().")
  end

  if fs.open and not (fs.read or fs.write) then
    error(E"Filesystem implements open() but doesn't implement read() or write().")
  end

  if fs.lstat and not fs.stat then
    error(E"Filesystem implements lstat() but doesn't implement stat().")
  end

  require("luafs.shortcuts").install(fs)
  require("luafs.panel").install(fs)

  for name, func in pairs(defaults) do
    if not fs[name] then
      fs[name] = func
    end
  end

end

local function register_filesystem(fs)
  validate_fs(fs)
  fsdb[fs.prefix:lower()] = fs
end

------------------------------------------------------------------------------------------

return {
  register_filesystem = register_filesystem,
  _do_stat = do_stat,
  _fs_iterator = function()
    return pairs(fsdb)
  end,
}
