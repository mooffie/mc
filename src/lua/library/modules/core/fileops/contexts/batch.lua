--[[

A minimal context.

Behaves like the shell's "cp" command.

]]

local function create_context()
  return {

    deref = false,

    preserve = true,

    notify_on_copy_start = function (ctx, src, dst)
      print(src.fname .. " -> " .. dst.fname)
    end,

    notify_on_move_start = function (ctx, src, dst)
      print(src.fname .. " -> " .. dst.fname)
    end,

    notify_on_delete_start = function (ctx, src)
      print("rm " .. src.fname)
    end,

    notify_on_file_progress = function (ctx, part, whole)
      -- You could do "print(part .. '/' .. whole)" here.
    end,

    decide_on_overwrite = function (ctx, src, dst)
      return "overwrite"
    end,

    decide_on_io_error = function (ctx, errmsg)
      return "skip"
    end,

    decide_on_partial = function (ctx, src, dst)
      return "delete"
    end,

    decide_on_non_empty_dir_deletion = function (ctx, src)
      return "delete"
    end,

    start = function (ctx, co)
      while true do
        local ok, reason = coroutine.resume(co)
        if not ok then
          error(debug.traceback(co, reason), 2)  -- See similar code (and explanation) in core/mcscript.lua.
        end
        if ok and reason == "terminated" then
          -- The task was aborted.
          break
        end
        if coroutine.status(co) == "dead" then
          -- The task has finished. Was not aborted.
          break
        end
      end
    end

  }
end

return {
  create_context = create_context,
}
