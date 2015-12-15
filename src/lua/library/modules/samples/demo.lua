--[[

This module introduces the user to MC/Lua and offers him to load some
"factory defaults" scripts.

It only kicks in if MC/Lua is run "for the first time".

This module is called from core/_bootstrap.lua as follows:

    require('samples.demo').run()

Tip:

To fool the module to think that you're running MC/Lua "for the first
time", launch mc with:

    $ MC_LUA_USER_DIR=dummy mc

(This will make it think you haven't yet created your Lua user directory.
Assuming, of course, that ./dummy doesn't exist.)

]]

local M = {}

local msg_question = T[[
Hi!

I'm MC with Lua support. Yes, I can talk!

It seems that you're running me for the first time, or something of the
sort. The directory where you're supposed to put your own scripts that
make me whirl and sing and dance doesn't exist:

    @USER_DIR

Until you create it I'll pretend you're running me for the first time,
and I'll bother you with the following question whenever you start me:

Do you want me to load some "factory defaults" scripts that will juice me
up and make you happy?
]]

local msg_done = T[[
Good, I knew I could trust you! Some things you can try out:

C-x r      Visual rename
C-x c      Calculator
Alt-PgUP   Recently visited files
Alt-r      Ruler
C-x g b    A game

There are many more features. You can even mouse-drag dialogs.
]]

local function prepare_msg(msg)
  return (msg
    :gsub('@[a-zA-Z_]+', {
      ['@USER_DIR'] = conf.dirs.user_lua,
    })
    :gsub('%s+$', '')  -- trim
  )
end

------------------------------------------------------------------------------

local function add_field_to_panel(pnl, fname)
   pnl.list_type = 'custom'
   local fmt = pnl.custom_format
   if not fmt:find(fname) then
     -- We add it right after the 'name' field.
     fmt = fmt:gsub('name', 'name' .. ' ' .. fname .. ' ')
   end
   pnl.custom_format = fmt
end

local function add_field(fname)
  if ui.Panel.left then
    add_field_to_panel(ui.Panel.left, fname)
  end
  if ui.Panel.right then
    add_field_to_panel(ui.Panel.right, fname)
  end
end

------------------------------------------------------------------------------

local function run_done_dlg()
  local dlg = ui.Dialog(T"Done.")

  local chk_modeline = ui.Checkbox(T"'&modeline' for the editor")
  local chk_screensaver = ui.Checkbox(T"&screensaver (3 minutes)")
  local chk_pretty_icons = ui.Checkbox(T"Pretty dialog icons")

  local chk_field_st = ui.Checkbox(T'"St" panel field (&git status)')
  local chk_field_dur = ui.Checkbox(T'"&Duration" panel field (mplayer)')

  dlg:add(ui.Label(prepare_msg(msg_done)))
  dlg:add(ui.Space())
  dlg:add(ui.Groupbox(T"Additional stuff you can enable now:"):add(
    ui.HBox():add(
      ui.VBox():add(
        chk_modeline,
        chk_screensaver,
        chk_pretty_icons
      ),
      ui.VBox():add(
        chk_field_st,
        chk_field_dur
      )
    )
  ))
  dlg:add(ui.Buttons():add(
    ui.Button{T"Cool, thanks.", type='default', result=true},
    ui.Button{T"Show me what you've loaded", result='show'}
  ))

  if dlg:run() then
    if chk_screensaver.checked then
      require('samples.screensavers.clocks.analog').install(3*60*1000)
    end
    if chk_modeline.checked then
      require('samples.editbox.modeline')
    end
    if chk_pretty_icons.checked then
      local dicons = require('samples.accessories.dialog-icons')
      if tty.is_utf8() and os.getenv('DISPLAY') then  -- 'DISPLAY' check excludes Linux console.
        dicons.style.char.close = '⚫'  -- Other nice possibilities: ●, ◾
        dicons.style.char.brackets = '╮ ╰'
        dicons.style.icons_margins = 0
      end
      dicons.show_close = true
    end
    if chk_field_dur.checked then
      add_field('|mp_duration')
    end
    if chk_field_st.checked then
      add_field('gitstatus')
    end
    if dlg.result == 'show' then
      mc.edit(utils.path.module_path 'samples.official-suggestions')
    end
  end
end

------------------------------------------------------------------------------

local function run_question_dlg()
  local dlg = ui.Dialog(T"Welcome")

  dlg:add(ui.Label(prepare_msg(msg_question)))
  dlg:add(ui.Buttons():add(
    ui.Button{T"&Sure, load 'em up!", type='default', result='load'},
    ui.Button{T"&No.", result=false},
    ui.Button{T"Say, can I &play?", on_click = function()
      require('samples.games.blocks').run()
    end}
  ))

  if dlg:run() then
    require('samples.official-suggestions')
    tty.redraw()  -- so the user sees the new features at the background (scrollbar etc).
    run_done_dlg()
  end
end

------------------------------------------------------------------------------

local function is_file_missing(path)
  local _, errmsg, errcode = fs.stat(path)
  return (errcode == fs.ENOENT)
end

function M.run()
  if is_file_missing(conf.dirs.user_lua) and not mc.is_standalone() then
    --
    -- We postpone the dialog till the panel/editor/viewer is
    -- showing. It's prettier.
    --
    -- It's possible that an error message will welcome the user. E.g.,
    -- the user adds some git fields to his custom listing format, but
    -- the next time he launches MC the git module isn't loaded and MC
    -- complains "User supplied format looks invalid". So we use an
    -- interval to repeatedly check whether it's an error dialog that's
    -- showing.
    --
    local itvl = nil
    itvl = timer.set_interval(function()
      if #ui.Dialog.screens ~= 0 then  -- Otherwise it's some error dialog (which we don't want to obscure).
        itvl:stop()
        timer.unlock()
        run_question_dlg()
        tty.refresh()
      end
    end, 500)
  end
end

------------------------------------------------------------------------------

return M
