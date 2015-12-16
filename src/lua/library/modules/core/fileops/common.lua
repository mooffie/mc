--[[

Common functions shared by all file operations.

]]

local append = table.insert
local bor = require("utils.bit32").bor
local basename = require("utils.path").basename

local fs = require "fs"
local const = fs

local DEFAULT_BUFSIZ = 1024*1024

local failure_messages = {
  -- The strings here were copied from the C source so they're already
  -- translated.
  open = T"Cannot open source file \"%s\"\n%s",
  create = T"Cannot create target file \"%s\"\n%s",
  read = T"Cannot read source file\"%s\"\n%s",
  write = T"Cannot write target file \"%s\"\n%s",
  closetrg = T"Cannot close target file \"%s\"\n%s",
  mkdir = T"Cannot create target directory \"%s\"\n%s",
  rmdir = T"Cannot remove directory \"%s\"\n%s",
  unlink = T"Cannot remove file \"%s\"\n%s",
  statsrc = T"Cannot stat source file \"%s\"\n%s",
  readlink = T"Cannot read source link \"%s\"\n%s",
  symlink = T"Cannot create target symlink \"%s\"\n%s",
  -- MC doesn't have the following string. MC is silent in this case (this
  -- should be considered a bug).
  opendir = T"Cannot read directory \"%s\"\n%s",
}

--
-- You should envelope syscalls in try_io(). It handles errors.
--
-- (We don't use an exception-based solution as they don't work across
-- C/Lua boundaries when using coroutines. This was purportedly addressed in
-- Lua 5.2. Google: "pcall coroutine lua".)
--
local function try_io(ctx, operation, fname, result, errmsg, errcode)
  assert(failure_messages[operation])
  assert(fname)

  if not result then
    local template = failure_messages[operation]
    -- We don't use 'errmsg' but strerror(): the 'template' already contains the file's path.
    local choice = ctx:decide_on_io_error(template:format(fname, fs.strerror(errcode)))
    if choice == "abort" then
      coroutine.yield("terminated")
    elseif choice == "skip" then
      -- Nothing to do.
    else
      error("Invalid choice " .. choice)
    end
  end
  return result
end

--
-- Copies a file's attributes.
--
local function copy_attributes(ctx, src, dst)
  -- We don't check for errors because too many file systems don't support
  -- all attributes.
  -- (What MC itself does is use filegui.c:filegui__check_attrs_on_fs() to
  -- determine the default value for the "Preserve attributes" checkbox.)
  fs.chmod(dst.fname, src.stat.perm)
  fs.utime(dst.fname, src.stat.mtime, src.stat.atime)
  fs.chown(dst.fname, src.stat.uid, src.stat.gid)
end

--
-- Copies a single, normal file. Returns 'true' on success.
--
local function copy_regular_file(ctx, src, dst, overwrite_choice)

  if dst.stat then
    if (dst.stat.dev == src.stat.dev) and (dst.stat.ino == src.stat.ino) then
      ctx:decide_on_io_error(T"\"%s\"\nand\n\"%s\"\nare the same file":format(src.fname, dst.fname))
      return
    end
  end

  local count_read = 0

  -- We're using the fs.File object, whose destructor closes the file. We could
  -- use the fs.filedes.* functions but then, if an error ensued and we simply
  -- "return"ed, the file descriptor would stay open.

  local s = try_io(ctx, "open", src.fname, fs.open(src.fname))
  if not s then return end

  local creation_flags = overwrite_choice == "reget"
                           and bor(const.O_WRONLY, const.O_APPEND)
                           or  bor(const.O_WRONLY, const.O_CREAT, const.O_TRUNC)

  local d = try_io(ctx, "create", dst.fname, fs.open(dst.fname, creation_flags))
  if not d then return end

  if overwrite_choice == "reget" then
    if s:seek("set", dst.stat.size) then
      count_read = dst.stat.size
    else
      -- Cannot seek. Fallback to normal copying.
      return copy_regular_file(ctx, src, dst, nil)
    end
  end

  local function decide_on_partial()
    if ctx:decide_on_partial(src, dst) == "delete" then
      fs.unlink(dst.fname)
    end
  end

  while true do

    local buf = try_io(ctx, "read", src.fname, s:sysread(ctx.BUFSIZ or DEFAULT_BUFSIZ))
    if not buf then return end

    if buf:len() == 0 then  -- EOF
      break
    end

    if not try_io(ctx, "write", dst.fname, d:syswrite(buf)) then
      decide_on_partial()
      return
    end

    count_read = count_read + buf:len()
    ctx:notify_on_file_progress(count_read, src.stat.size)

    local command = coroutine.yield()

    if command == "abort" then
      decide_on_partial()
      coroutine.yield("terminated")
    elseif command == "skip" then
      decide_on_partial()
      return -- on to the next file.
    end

  end

  s:close()
  if not try_io(ctx, "closetrg", dst.fname, d:close()) then return end

  if ctx.preserve then
    copy_attributes(ctx, src, dst)
  end

  return true
end

--
-- Copies a symlink. Returns 'true' on success.
--
local function copy_link(ctx, src, dst)
  local contents = try_io(ctx, "readlink", src.fname, fs.readlink(src.fname))
  if not contents then return end
  if dst.stat and not try_io(ctx, "unlink", dst.fname, fs.unlink(dst.fname)) then return end
  if not try_io(ctx, "symlink", dst.fname, fs.symlink(contents, dst.fname)) then return end
  return true
end

--
-- Copies a special file. Returns 'true' on success.
--
local function copy_special_file(ctx, src, dst)
  -- Feature not supported yet.
  ctx:decide_on_io_error(T"I don't know how to copy files of type '%s'":format(src.ftype))
  -- @todo: Now that we have fs.mknod() we could create such files.
  return false
end

--
-- Before copy() or move() do their job they adjust their arguments using
-- this utility function.
--
-- E.g., the src and dst, as in:
--
--   copy('one.txt', 'two')
--   copy({'one.txt', 'another.txt'}, 'two')
--   copy({'one.txt', 'another.txt'}, {'two', three'})  -- must have same length.
--   copy('one.txt', {'two'})     -- ERROR: invalid!
--
-- are turned into
--
--   { { source = 'one.txt', target = 'two' }, ... }
--
local function _canonical_arguments(src, dst)
  local united = {}

  assert(src, E"Missing 'src' argument.")
  assert(dst, E"Missing 'dst' argument.")

  assert(type(src) ~= "function" and type(dst) ~= "function",
    E"Are you trying to feed me an iterator? Use tglob()/dir() instead of glob()/files().")

  if type(src) ~= 'table' and type(dst) ~= 'table' then
    united = {
      {
        source = src,
        target = dst
      }
    }
  end

  if type(src) == 'table' and type(dst) == 'table' then
    assert(#src == #dst, E"Illegal arguments: 'dst' and 'src' are tables of different lengths.")
    for i = 1, #src do
      append(united, {
        source = src[i],
        target = dst[i]
      })
    end
  end

  if type(src) == 'table' and type(dst) ~= 'table' then
    for i = 1, #src do
      append(united, {
        source = src[i],
        target = dst
      })
    end
  end

  if type(src) ~= 'table' and type(dst) == 'table' then
    error(E"Illegal arguments: 'dst' is a table but 'src' is not.")
  end

  return united
end

local function join(dir, rest)
  return dir .. "/" .. rest
end

--
-- Usually we need a 'stat' beside the file name. So we represent a file
-- as a table with all the needed fields:
--
--   { fname = ..., stat = ..., ftype = ... }
--
-- 'ftype' is the 'type' member of 'stat' (it's not called just 'type' because
-- an editor may syntax highlight it distracting the reader).
--
-- ADDITIONALLY, if the destination is a directory, a new destination is
-- determined having the basename of the original.
--
local function _build_file_vars(ctx, src, dst, dst_is_final)

  src = { fname = src }
  dst = { fname = dst }

  dst.ftype = fs.stat(dst.fname, "type")
  if not dst_is_final then
    if dst.ftype == "directory" then
      dst.fname = join(dst.fname, basename(src.fname))
      dst.ftype = fs.stat(dst.fname, "type")
    end
  end
  dst.stat = fs.stat(dst.fname)

  local src_stat_f = ctx.deref and fs.stat or fs.lstat
  src.stat = try_io(ctx, "statsrc", src.fname, src_stat_f(src.fname))
  src.ftype = src.stat and src.stat.type

  return src, dst

end


--
-- Decides what to do when the destination exists.
--
-- The answer, if not handled immediately here, is passed on to
-- copy_rrgular_file().
--

local valid_overwrite_choices = {
  abort=true,
  skip=true,
  overwrite=true,
  update=true,  -- Overwrite only if source is newer.
  reget=true,   -- If target is smaller, append the rest of the file. It's like
                -- stop/resume in downloading apps. Useful for network filesystems.
}

local function decide_on_overwrite(ctx, src, dst)

  if dst.stat and src.stat and dst.ftype ~= "directory" then

    local choice = ctx:decide_on_overwrite(src, dst)

    if not valid_overwrite_choices[choice] then
      error("Invalid choice " .. choice)
    end

    if choice == "abort" then
      coroutine.yield("terminated")
    -- should we put the "update" here, or in copy_regular_file? here it would work for symlinks too.
    elseif choice == "update" then
      if src.stat.mtime <= dst.stat.mtime then
        -- Target file is up-to-date.
        choice = "skip"
      end
    end

    return choice

  end

end

return {

  copy_regular_file = copy_regular_file,
  copy_special_file = copy_special_file,
  copy_link = copy_link,
  copy_attributes = copy_attributes,

  try_io = try_io,
  _build_file_vars = _build_file_vars,
  _canonical_arguments = _canonical_arguments,
  decide_on_overwrite = decide_on_overwrite,
  join = join,

}
