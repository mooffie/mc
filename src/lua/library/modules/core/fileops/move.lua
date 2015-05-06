--[[

Move/rename files.

(mc.mv() is an "easy" way to use it.)

]]

local fs = require "fs"
local errors = fs

local copy_regular_file, copy_attributes, copy_link, copy_special_file, join,
  try_io, decide_on_overwrite, _build_file_vars, _canonical_arguments = import_from("fileops.common", {
    'copy_regular_file','copy_attributes', 'copy_link', 'copy_special_file', 'join',
  'try_io', 'decide_on_overwrite', '_build_file_vars', '_canonical_arguments'
})

--
-- Move an "entry" (that is, a file or a directory).
--
local function move_entry(ctx, src, dst, dst_is_final)

  src, dst = _build_file_vars(ctx, src, dst, dst_is_final)
  if not src.stat then
    -- Missing file or broken symlink (error already reported by _build_file_vars).
    return
  end

  ctx:notify_on_move_start(src, dst)

  local overwrite_choice = decide_on_overwrite(ctx, src, dst)
  if overwrite_choice == "skip" then
    return
  end

  -- First, try to move the file by renaming it. This only works within devices.
  local success, _, errcode = fs.rename(src.fname, dst.fname)
  if success then return true end  -- SUCCESS

  if errcode == errors.EINVAL then
    -- "EINVAL The new pathname contained a path prefix of the old, or, more
    -- generally, an attempt was made to make a directory a subdirectory of itself."
    ctx:decide_on_io_error(T"An attempt was made to make '%s' a subdirectory ('%s') of itself.":format(src.fname, dst.fname))
    return
  end

  -- Renaming the file failed. So resort to copying + deleting.
  --
  -- We only need to do this if rename() has failed with the EXDEV error code
  -- (trying to rename across devices), but according to a comment in MC's file.c,
  -- rename() may return some other code for NFS; so we do this unconditionally.

  if src.ftype == "regular" then

    if copy_regular_file(ctx, src, dst, overwrite_choice) then
      if not try_io(ctx, "unlink", src.fname, fs.unlink(src.fname)) then return end
      return true  -- SUCCESS
    end

  elseif src.ftype == "directory" then

    if dst.ftype == "directory" then
      -- No need to create this dir.
    elseif dst.ftype == nil then
      if not try_io(ctx, "mkdir", dst.fname, fs.mkdir(dst.fname)) then return end
    else
      ctx:decide_on_io_error(T"Destination \"%s\" must be a directory\n%s":format(dst.fname, ""))
      return
    end

    local move_succeeded = true

    -- We prefer posix.opendir() to posix.files() because we want to see the error.
    local dirh = try_io(ctx, "opendir", src.fname, fs.opendir(src.fname))
    if not dirh then return end
    for ent in dirh.next, dirh do
      if not move_entry(ctx, join(src.fname, ent), join(dst.fname, ent), true) then
        move_succeeded = false
      end
    end

    -- We set the directory permission _after_ copying its contents because its
    -- write permission could be turned off.
    if ctx.preserve then
      copy_attributes(ctx, src, dst)
    end

    if move_succeeded then
      if not try_io(ctx, "rmdir", src.fname, fs.rmdir(src.fname)) then return end
      return true  -- SUCCESS
    end

  elseif src.ftype == "link" then

    if copy_link(ctx, src, dst) then
      if not try_io(ctx, "unlink", src.fname, fs.unlink(src.fname)) then return end
      return true  -- SUCCESS
    end

  else

    if copy_special_file(ctx, src, dst) then
      if not try_io(ctx, "unlink", src.fname, fs.unlink(src.fname)) then return end
      return true  -- SUCCESS
    end

  end

end

local function do_move(ctx, src, dst)
  for _, op in ipairs(_canonical_arguments(src, dst)) do
    move_entry(ctx, op.source, op.target)
  end
end

--[[

For future reference, here's a summary of the various combinations
fs.rename() (which is the C library's rename(2)) can be called with:

  F -> new:     ok
  F -> F:       ok
  F -> D:       FAIL   "EISDIR  newpath is an existing directory, but oldpath is not a directory."
  D -> new:     ok
  D -> F:       FAIL   "EISDIR"
  D -> D-empty: ok
  D -> D-full:  FAIL   "ENOTEMPTY or EEXIST"

]]

local function move(ctx, src, dst)
  ctx.operation_name = "move"
  local co = coroutine.create(function()
    do_move(ctx, src, dst)
    -- @todo: we could return something useful here.
  end)
  return ctx:start(co)
end

return {
  move = move,
}
