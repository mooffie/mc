--[[

Copy files.

(mc.cp() is an "easy" way to use it.)

]]

local fs = require "fs"

local copy_regular_file, copy_attributes, copy_link, copy_special_file, join,
  try_io, decide_on_overwrite, _build_file_vars, _canonical_arguments = import_from("fileops.common", {
    'copy_regular_file','copy_attributes', 'copy_link', 'copy_special_file', 'join',
  'try_io', 'decide_on_overwrite', '_build_file_vars', '_canonical_arguments'
})

--
-- Copy an "entry" (that is, a file or a directory). All four combinations
-- (f->d, f->f, d->d, d->f) are handled.
--
local function copy_entry(ctx, src, dst, dst_is_final)

  src, dst = _build_file_vars(ctx, src, dst, dst_is_final)
  if not src.stat then
    -- Missing file or broken symlink (error already reported by _build_file_vars).
    return
  end

  ctx:notify_on_copy_start(src, dst)

  local overwrite_choice = decide_on_overwrite(ctx, src, dst)
  if overwrite_choice == "skip" then
    return
  end

  if src.ftype == "regular" then

    copy_regular_file(ctx, src, dst, overwrite_choice)

  elseif src.ftype == "directory" then

    if dst.ftype == "directory" then
      -- No need to create this dir.
    elseif dst.ftype == nil then
      if not try_io(ctx, "mkdir", dst.fname, fs.mkdir(dst.fname)) then return end
    else
      ctx:decide_on_io_error(T"Destination \"%s\" must be a directory\n%s":format(dst.fname, ""))
      return
    end

    -- We prefer fs.opendir() to fs.files() because we want to see the error.
    local dirh = try_io(ctx, "opendir", src.fname, fs.opendir(src.fname))
    if not dirh then return end
    for ent in dirh.next, dirh do
      copy_entry(ctx, join(src.fname, ent), join(dst.fname, ent), true)
    end

    -- We set the directory permission _after_ copying its contents because its
    -- write permission could be turned off.
    if ctx.preserve then
      copy_attributes(ctx, src, dst)
    end

  elseif src.ftype == "link" then

    copy_link(ctx, src, dst)

  else

    copy_special_file(ctx, src, dst)

  end

end

local function do_copy(ctx, src, dst)
  for _, op in ipairs(_canonical_arguments(src, dst)) do
    copy_entry(ctx, op.source, op.target)
  end
end

local function copy(ctx, src, dst)
  ctx.operation_name = "copy"
  local co = coroutine.create(function()
    do_copy(ctx, src, dst)
    -- @todo: we could return something useful here.
  end)
  return ctx:start(co)
end

return {
  copy = copy,
}
