--[[

Delete files.

(mc.rm() is an "easy" way to use it.)

]]

local fs = require "fs"

local try_io, _build_file_vars, join = import_from("fileops.common", { 'try_io', '_build_file_vars', 'join' })

--
-- Delete an "entry" (that is, a file or a directory).
--
local function delete_entry(ctx, src, delete_recursively)

  src = _build_file_vars(ctx, src, "/NON-EXISTENT", true)
  if not src.stat then
    -- Missing file or broken symlink (error already reported by _build_file_vars).
    return
  end

  ctx:notify_on_delete_start(src)

  if src.ftype == "directory" then

    -- Deleting a directory.

    -- One approach to detect a non empty dir would be to fs.rmdir(src.fname)
    -- and check for ENOTEMPTY. But this is purportedly unreliable on NFS (see
    -- comment in file.c: "The old way to detect a non empty directory was [...]"

    local files_within = fs.dir(src.fname)

    local contents_deleted = true

    if files_within then

      if #files_within > 0 and not delete_recursively then
        local choice = ctx:decide_on_non_empty_dir_deletion(src)
        if choice == "skip" then
          return
        elseif choice == "abort" then
          coroutine.yield("terminated")
        else
          assert(choice == "delete")
          delete_recursively = true
        end
      end

      for _, f in ipairs(files_within) do
        if not delete_entry(ctx, join(src.fname, f), delete_recursively) then
          contents_deleted = false
        end
      end

    end

    if contents_deleted then
      if try_io(ctx, "rmdir", src.fname, fs.rmdir(src.fname)) then
        return true  -- SUCCESS
      end
    end

  else
    -- Deleting a normal file.

    if coroutine.yield() == "abort" then
      coroutine.yield("terminated")
    end

    if try_io(ctx, "unlink", src.fname, fs.unlink(src.fname)) then
      return true  -- SUCCESS
    end
  end

end

local function do_delete(ctx, src)
  if type(src) ~= "table" then
    src = { src }
  end
  for _, f in ipairs(src) do
    delete_entry(ctx, f)
  end
end

local function delete(ctx, src)
  ctx.operation_name = "delete"
  local co = coroutine.create(function()
    do_delete(ctx, src)
    -- @todo: we could return something useful here.
  end)
  return ctx:start(co)
end

return {
  delete = delete,
}
