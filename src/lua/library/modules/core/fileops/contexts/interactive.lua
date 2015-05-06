--[[

A UI context.

Mimics MC's own interface.

]]

local query = require("prompts").query

local dialog_titles = {
  copy = Q"DialogTitle|Copy",
  move = Q"DialogTitle|Move",
  delete = Q"DialogTitle|Delete"
}

local function dialog_title(ctx)
  return assert(dialog_titles[ctx.operation_name])
end

local function decide_on_overwrite(ctx, src, dst)

  if ctx.for_all["overwrite"] then
    return ctx.for_all["overwrite"]
  end

  local format_file_date = require("utils.text").format_file_date
  local bor = require("utils.bit32").bor

  local dlg = ui.Dialog { T"File Exists", colorset = "alarm", padding = 2 }

  dlg:add(
    ui.Label { T"Target file already exists!" .. "\n" .. dst.fname, pos_flags = bor(ui.WPOS_CENTER_HORZ, ui.WPOS_KEEP_TOP) },
    ui.ZLine(),
    ui.Label(T"New     : %s, size %s":format(format_file_date(src.stat.mtime), src.stat.size)),
    ui.Label(T"Existing: %s, size %s":format(format_file_date(dst.stat.mtime), dst.stat.size)),
    ui.ZLine()
  )
  dlg:add(ui.HBox():add(
    ui.Label(T"Overwrite this target?"),
      ui.Button{T"&Yes",result={"overwrite"}},
      ui.Button{T"&No", result={"skip"}},
      (dst.stat.size ~= 0 and dst.stat.size < src.stat.size) and ui.Button{T"&Reget",result={"reget"}} or nil     -- MC omits this button for directories.
  ))
  dlg:add(ui.ZLine())
  dlg:add(ui.HBox():add(
    ui.Label(T"Overwrite all targets?"),
      -- Note that the 'result' property can be anything, even a table. We use this fact here.
      ui.Button{T"A&ll",result={"overwrite",for_all=true}},
      ui.Button{T"&Update",result={"update",for_all=true}},
      ui.Button{T"Non&e",result={"skip",for_all=true}}
  ))

  dlg:add(ui.Buttons():add(ui.Button{T"&Abort",result=false}))

  local choice = dlg:run() or {"abort"}

  if choice.for_all then
    ctx.for_all["overwrite"] = choice[1]
  end

  return choice[1]

end

local function decide_on_non_empty_dir_deletion(ctx, src)

  if ctx.for_all["non_empty_dir_deletion"] then
    return ctx.for_all["non_empty_dir_deletion"]
  end

  local choice = query({dialog_title(ctx), colorset="alarm"},
                       T"Directory \"%s\" not empty.\nDelete it recursively?":format(src.fname),
                       {
                         {T"&Yes",  {"delete"}},
                         {T"&No",   {"skip"}},
                         {T"A&ll",  {"delete", for_all=true}},
                         {T"Non&e", {"skip", for_all=true}},
                         {T"&Abort"}
                       }
                      ) or {"abort"}

  if choice.for_all then
    ctx.for_all["non_empty_dir_deletion"] = choice[1]
  end

  return choice[1]

end

local function decide_on_partial(ctx, src, dst)

  return query({dialog_title(ctx), colorset="alarm" },
               T"Incomplete file was retrieved. Keep it?",
               {
                 { T"&Delete", "delete" },
                 { T"&Keep" }
               }) or "keep"

end

local function decide_on_io_error(ctx, errmsg)

  if ctx.for_all["io_error"] then
    return ctx.for_all["io_error"]
  end

  local choice = query({T"Error", colorset="alarm"},
                       errmsg,
                       {
                         {T"&Skip", {"skip"}},
                         {T"Ski&p all", {"skip", for_all=true}},
                         {T"&Abort"}
                       }
                      ) or {"abort"}

  if choice.for_all then
    ctx.for_all["io_error"] = choice[1]
  end

  return choice[1]

end

local function start(ctx, co)

  local dlg = ui.Dialog(dialog_title(ctx))

  local lbl_src = ui.Label {expandx=true, auto_size=false}
  local lbl_dst = ui.Label {expandx=true, auto_size=false}

  if ctx.operation_name ~= "delete" then

    -- Copy/move dialog.

    dlg:add(ui.Label(T"Source"))
    dlg:add(lbl_src)
    dlg:add(ui.Label(T"Target"))
    dlg:add(lbl_dst)
    local gauge = ui.Gauge {expandx = true}
    dlg:add(ui.HBox({expandx = true}):add(ui.Space(2), gauge, ui.Space(2)))

    ctx.notify_on_copy_start = function (ctx, src, dst)
      -- @todo: see filegui.c:file_progress_show_target() for how to properly
      -- truncate filenames for display. (Tip: we do have VPath:to_str().)
      lbl_src.text = src.fname
      lbl_dst.text = dst.fname
      dlg:refresh()
    end
    ctx.notify_on_move_start = ctx.notify_on_copy_start

    ctx.notify_on_file_progress = function (ctx, part, whole)
      local perc = 100 * part / whole
      gauge.value = perc
      dlg:refresh()
    end

  else

    -- Delete dialog.

    dlg:add(lbl_src)

    ctx.notify_on_delete_start = function (ctx, src)
      lbl_src.text = src.fname
      dlg:refresh()
    end

  end

  local function close_dialog()
    -- See documentation for on_idle as to why we must set to nil.
    dlg.on_idle = nil
    dlg:close()
  end

  local function run_next_slice(command)
    tty.refresh()
    if coroutine.status(co) == "suspended" then
      local ok, reason = coroutine.resume(co, command)
      if ok then
        if reason == "terminated" then
          close_dialog()
        end
      else
        close_dialog()
        error(debug.traceback(co, reason), 3)  -- See similar code (and explanation) in core/mcscript.lua.
      end
    elseif coroutine.status(co) == "dead" then
      close_dialog()
    end
  end

  local on_idle_handler = function()
    run_next_slice()
  end

  dlg.on_idle = on_idle_handler

  if ctx.passive then

    -- In 'passive' mode we forbid the user from closing the dialog thereby
    -- aborting the process.
    dlg.on_validate = function()
      if coroutine.status(co) == "suspended" then
        return false
      else
        -- But we still need to allow closing when the process is
        -- dead already.
        return true
      end
    end

  else

    -- When the user closes the dialog (when not in 'passive' mode), we
    -- trigger any cleanup tasks in the process (e.g., asking about keeping
    -- partially copied files) by sending it the "abort" signal.
    dlg.on_validate = function()
      if coroutine.status(co) == "suspended" then
        run_next_slice("abort")
      end
      return true
    end

  end

  if not ctx.passive then

    local btns = ui.Buttons()

    if ctx.operation_name ~= "delete" then

      -- Buttons for a copy/move dialog.

      dlg:add(btns:add(
        ui.Button{"&Skip", on_click=function()
          dlg.on_idle = on_idle_handler  -- Potentially undo the "Suspend" button.
          run_next_slice("skip")
        end},

        ui.Button{ T"S&uspend", on_click=function(self)
          if dlg.on_idle then
            dlg.on_idle = nil
            self.text = T"Con&tinue"
          else
            dlg.on_idle = on_idle_handler
            self.text = T"S&uspend"
          end
          btns:repack()
        end},

        ui.Button{"&Abort", result=false}
        -- , ui.Button{"&Abort, but don't close dialog", on_click=function() run_next_slice("abort") end}
      ))

    else

      -- Buttons for a delete dialog.

      dlg:add(btns:add(
        ui.Button{"&Abort", result=false}
      ))

    end

  end

  -- The following metrics are taken from filegui.c:file_op_context_create_ui()
  dlg:set_dimensions(nil, nil, math.max(math.floor(tty.get_cols() * 2 / 3), dlg:preferred_cols()), nil)

  dlg:run()

end

local function create_context()
  return {

    deref = false,

    preserve = true,

    for_all = {},

    decide_on_overwrite = decide_on_overwrite,

    decide_on_io_error = decide_on_io_error,

    decide_on_partial = decide_on_partial,

    decide_on_non_empty_dir_deletion = decide_on_non_empty_dir_deletion,

    start = start,

  }
end

return {
  create_context = create_context,
}
