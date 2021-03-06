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

local msg_welcome = T[[
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

local msg_menu1 = T[[
Good, I knew I could trust you!

I've loaded some goodies. If you enable the "Help ticker" (below), I'll
list some keyboard shortcuts on the screen while you're working.

Tip: Enable the git status field (below) if you're a developer.

There are many more features in me beside those you'll shortly see.
Browse my 'snippets' and 'samples' folders, or read my user manual!
You can return to this screen later by restarting Lua (C-x l).
]]

local msg_menu2 = T[[
Marvelous, you're still with me! Here are a few more modules you may want
to enable. C'mon, tick them all! Don't be shy!
]]

local function prepare_msg(msg)
  return (msg
    :gsub('@[a-zA-Z_]+', {
      ['@USER_DIR'] = conf.dirs.user_lua,
    })
    :gsub('%s+$', '')  -- trim
  )
end

----------------------------------- Fields -----------------------------------

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

-------------------------------- Help ticker ---------------------------------

local help_panel = T[[
                          ** Shortcuts for the panel: **

C-x r  Visual rename     | C-x S   Size calculator      | C-x f    Follow (a symlink or panelized item)
C-p    Visual panelize   | M-pgdn  Save/restore panels  | C-x C-f  Follow (in the other panel)
&      Restore selection | C-]     "filter as you type" | C-x M-s  Scan image]]

local help_panel_style = { color = 'white, green', hicolor = 'white, color64' }

local help_any = T[[
                            ** Shortcuts anywhere: **

M-pgup  Recently visited files | C-s      "find as you type" for listboxes
C-x c   Calculator             | C-x l    Restart Lua |  -> Type :help for more <-
M-r     Ruler                  | C-x g b  Game        | --> Drag dialogs with the mouse <--]]

local help_any_style = { color = 'yellow, magenta', hicolor = 'yellow, color53' }

local help_edit = T[[
                         ** Shortcuts for the editor: **

C-x r  Visual replace    | F12    Linter         | ESC !    Spellcheck document
C-x d  Dictionary        | C-\    Functions list | ESC $    Spellcheck word
C-x i  Unicode char info | ESC *  Highlight word | C-s C-s  Clear spelling highlights]]

local help_edit_style = { color = 'black, brown', hicolor = 'black, color179' }

local panel_help_pages = {
  { text = help_panel, style = help_panel_style },
  { text = help_any,   style = help_any_style },
}

local function graphics(s)
  return s:gsub('|', tty.skin_get('Lines.vert', '|'))
end

local function create_ticker()

  local counter = 1
  require('samples.accessories.ticker').new {
    update = function(label)
      counter = counter + 1
      local page = panel_help_pages[counter % #panel_help_pages + 1]
      label.text = graphics(page.text)
      label.style = tty.style(page.style)
    end,
    lines = 5,
    interval = 10*1000,  -- Flip page every 10 seconds.
  }
  require('samples.libs.docker').trigger_layout()

  require('samples.ui.extlabel')
  require('samples.libs.docker-editor').register_widget('north', function()
    return ui.ExtLabel{
      graphics(help_edit),
      style = tty.style(help_edit_style),
      rows = 5,
    }
  end)

end

--------------------------------- Dialogs ------------------------------------

local default_screensaver_minutes = 3

local function run_menu1_dlg()
  local dlg = ui.Dialog(T"Done.")

  local chk_help_ticker = ui.Checkbox{T"&Help ticker", checked=true}
  local chk_modeline = ui.Checkbox(T"'&modeline' for the editor")
  local chk_screensaver = ui.Checkbox(T"&Screensaver")
  local ipt_screensaver_minutes = ui.Input{default_screensaver_minutes, cols=2}
  local chk_pretty_icons = ui.Checkbox(T"&Pretty dialog icons")
  local chk_clock = ui.Checkbox(T"&Clock at corner")

  local chk_field_st = ui.Checkbox(T'"St" field (&git status)')
  local chk_field_dur = ui.Checkbox(T'"&Duration" field (mplayer)')
  local chk_field_bidi = ui.Checkbox(T'&BiDi name (bidiv)')

  dlg:add(ui.Label(prepare_msg(msg_menu1)))
  dlg:add(ui.Space())
  dlg:add(ui.Groupbox(T"Additional stuff you can enable now:"):add(
    ui.HBox():add(
      ui.VBox():add(
        chk_help_ticker,
        chk_modeline,
        ui.HBox{gap=0}:add(
          chk_screensaver,
          ui.Label(' ('),
          ipt_screensaver_minutes,
          ui.Label(' ' .. T'minutes'),
          ui.Label(')')
        ),
        chk_pretty_icons,
        chk_clock
      ),
      ui.Groupbox(T"Panel fields"):add(
        chk_field_st,
        chk_field_dur,
        chk_field_bidi
      )
    )
  ))
  dlg:add(ui.Buttons():add(
    ui.OkButton(T"Next..."),
    ui.Button{T"Show me what you've just loaded", on_click=function()
      mc.edit(utils.path.module_path 'samples.official-suggestions')
    end}
  ))

  if dlg:run() then
    if chk_help_ticker.checked then
      create_ticker()
    end
    if chk_clock.checked then
      require('samples.accessories.clock').install()
    end
    if chk_screensaver.checked then
      local minutes = tonumber(ipt_screensaver_minutes.text) or default_screensaver_minutes
      require('samples.screensavers.clocks.analog').install(minutes * 60 * 1000)
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
      if require('samples.fields.mplayer').is_installed then
        add_field('|mp_duration')
      else
        alert(E"It seems that the 'mplayer' program isn't installed.")
      end
    end
    if chk_field_st.checked then
      if require('samples.fields.git').is_installed then
        add_field('gitstatus')
      else
        alert(E"It seems that the 'git' program isn't installed.")
      end
    end
    if chk_field_bidi.checked then
      if not require('samples.fields.bidi').is_installed then
        alert(E"It seems that the 'bidiv' program isn't installed.")
      else
        -- Because of late-stage definition of the 'name' field, we
        -- call the following function. See its documentation.
        fields._reparse_format_string()
      end
    end
  end

  return dlg.result
end

------------------------------------------------------------------------------

local function run_menu2_dlg()
  local dlg = ui.Dialog(T"Just a sec!")

  local chk_github = ui.Checkbox{T'&GitHub-style "folder jumping"', checked=true}
  local chk_lynx = ui.Checkbox{T"Enhanced &Lynx-like motion", checked=true}
  local chk_unwind = ui.Checkbox(T"Un&Wind for the editor (easier editing of CR+LF files)")

  -- Tabs
  local chk_tabs_south = ui.Checkbox{T'Show the tabs bar at botto&m (not top)'}
  local chk_tabs_bindings = ui.Checkbox{T'&Keys: Make C-n open new tab; C-c close tab.'}
  local chk_tabs = ui.Checkbox{T'Enable &tabs', on_change=function(self)
    chk_tabs_south.enabled = self.checked
    chk_tabs_bindings.enabled = self.checked
  end}
  chk_tabs:on_change()

  dlg:add(ui.Label(prepare_msg(msg_menu2)))
  dlg:add(ui.Space())
  dlg:add(ui.Groupbox(T"Additional stuff you can enable now:"):add(
    chk_github,
    chk_lynx,
    chk_unwind,
    ui.Groupbox(T"Tabs"):add(
      chk_tabs,
      chk_tabs_south,
      chk_tabs_bindings
    )
  ))
  dlg:add(ui.Buttons():add(
    ui.OkButton(T"Cool, thanks!")
  ))

  if dlg:run() then
    if chk_lynx.checked then
      require('samples.accessories.lynx-keys')
    end
    if chk_unwind.checked then
      require('samples.editbox.unwind').install()
    end
    if chk_github.checked then
      require('samples.fields.github-folder-jumping')
      -- Because of late-stage definition of the 'name' field, we
      -- call the following function. See its documentation.
      fields._reparse_format_string()
    end
    if chk_tabs.checked then
      require('samples.accessories.tabs.default-key-bindings')
      require('samples.accessories.tabs.colon-commands')
      local tabs = require('samples.accessories.tabs.core')
      if chk_tabs_south.checked then
        tabs.region = "south"
      end
      if chk_tabs_bindings.checked then
        ui.Panel.bind('C-n', function() tabs.create_tab() end)
        ui.Panel.bind('C-c', function() tabs.close_tab() end)
      end
    end
  end

  return dlg.result
end

------------------------------------------------------------------------------

local function run_welcome_dlg()
  local dlg = ui.Dialog(T"Welcome")

  dlg:add(ui.Label(prepare_msg(msg_welcome)))
  dlg:add(ui.Buttons():add(
    ui.Button{T"&Sure, load 'em up!", type='default', result='load'},
    ui.Button{T"&No.", result=false},
    ui.Button{T"Say, can I &play?", on_click = function()
      require('samples.games.blocks').run()
    end}
  ))

  if dlg:run() then
    prompts.please_wait(T"Loading the goodies", function()
      require('samples.official-suggestions')
      -- Because of late-stage definition of the 'size' field (by module
      -- 'better-size'), we call the following function. See its documentation.
      fields._reparse_format_string()
    end)
  else
    prompts.flash(T"My! You're such a party breaker! :-(")
  end

  return dlg.result
end

--------------------------------- Startup ------------------------------------

function M.run()
  if not fs.file_exists(conf.dirs.user_lua) and not mc.is_standalone() then
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
      --
      -- We look for 'colorset ~= "alarm"' as we don't want to obscure
      -- error dialogs.
      --
      -- Note that '#ui.Dialog.screens ~= 0' alone would work, but only
      -- when starting MC, not when restarting Lua (as there's already a
      -- "screen" when restarting). But we use it too in case MC shows
      -- some other alert box (e.g., "I imported your old history") when
      -- starting.
      --
      -- @todo: We can simply check for ui.current_widget('Panel')!
      --
      if ui.Dialog.top.colorset ~= "alarm"
          and #ui.Dialog.screens ~= 0 then
        itvl:stop()
        timer.unlock()
        local _ = run_welcome_dlg() and run_menu1_dlg() and run_menu2_dlg()
        tty.refresh()
      end
    end, 500)
  end
end

------------------------------------------------------------------------------

return M
