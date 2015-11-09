--[[

Adds a help icon to dialogs that have a help page.

Also adds a close icon, if you ask it to.

The help icon, by default, appears as "[?]" at the top-right corner of
the dialog.

Installation:

    require('samples.accessories.dialog-icons').install()

Or, with customization:

    local dicons = require('samples.accessories.dialog-icons')
    if tty.is_utf8() then
      dicons.style.char.close = '⚫'  -- Other nice possibilities: ●, ◾
      dicons.style.char.brackets = '╮ ╰'
    end
    dicons.show_close = false  -- Don't show a close icon.
    dicons.install()

Rationalization:

Some dialogs have surprisingly useful help pages. Unfortunately, the user
doesn't have a way to know if a dialog has, or hasn't, a help page. This
module solves the problem by alerting the user with an icon when help is
available.

Known issues:

The icons may not work for the help viewer dialog. That's because its
interior foolishly overlaps the frame. Explained in 'dialog-drag.lua'.

]]

local M = {
  style = {
    color = {
      normal = {
        brackets = 'dialog._default_',
        symbol = 'dialog.dhotnormal',
      },
      alarm = {
        brackets = 'error._default_',
        symbol = 'error.errdhotnormal',
      },
      pmenu = {
        brackets = 'popupmenu._default_',
        symbol = 'popupmenu.menutitle',
      }
    },
    char = {
      -- The strings to use for the various UI elements.
      help = nil,
      close = nil,
      brackets = '[ ]',
    }
  },

  -- Which icons to show?
  show_help = true,
  show_close = true,
}

local function get_color(dlg, name)
  return tty.style((M.style.color[dlg.colorset] or M.style.color.normal)[name])
end

local function is_fullscreen(dlg)
  return dlg.x == 0 and dlg.y == 0 and dlg.cols == tty.get_cols() and dlg.rows == tty.get_rows()
end

--
-- A few useless help keys set on some common dialogs.
--
-- They serve no useful purpose and we don't want to mislead the user by
-- showing the help icon for them.
--
local bogus_help = {
  ["[Input Line Keys]"] = true,
  ["[QueryBox]"] = true,
  ["[History-query]"] = true,
}

------------------------------ The icon widget -------------------------------

local FrameIcon = ui.Custom.subclass("FrameIcon")

FrameIcon.__allowed_properties = {
  symbol = true,
}

function FrameIcon:init()
  self.symbol = '*'
  self.cols = 3
end

function FrameIcon:on_draw()
  local c = self:get_canvas()
  c:erase()
  c:set_style(get_color(self.dialog, 'brackets'))
  c:draw_string(M.style.char.brackets)  -- "[ ]"
  c:set_style(get_color(self.dialog, 'symbol'))
  c:goto_xy(1, 0)
  c:draw_string(self.symbol)
end

------------------------------------------------------------------------------

local bor = utils.bit32.bor

function M.install()

  ui.Dialog.bind('<<open>>', function(dlg)

    if dlg.data.skip_pyrotechnics or is_fullscreen(dlg) then
      return
    end

    -- Remember the focused widget.
    local focused = dlg.current

    local MARGIN = dlg.compact and 0 or 1

    if M.show_help and ((dlg.help_id and not bogus_help[dlg.help_id]) or dlg.on_help) then

      dlg:map_widget(ui.FrameIcon {
        symbol = M.style.char.help or '?',
        x = dlg.cols - MARGIN - 1 - 1 - 3,
        y = MARGIN,
        pos_flags = bor(ui.WPOS_KEEP_RIGHT, ui.WPOS_KEEP_TOP),
        on_click = function(self)
          self.dialog:command "help"
        end
      }:fixate())

    end

    if M.show_close then

      dlg:map_widget(ui.FrameIcon {
        symbol = M.style.char.close or (tty.is_utf8() and '×' or tty.skin_get('editor.window-close-char', 'x')),
        x = MARGIN + 1 + 1,
        y = MARGIN,
        on_click = function(self)
          --
          -- Note: we don't use :close(). Our :close() doesn't do
          -- 'h->ret_value = B_CANCEL' on the C side (as it shouldn't), so
          -- using it will lead some dialogs (Copy/Move) to think the user
          -- has OK'ed the action.
          --
          self.dialog:command "cancel"
        end
      }:fixate())

    end

    -- Restore the previously focused widget.
    -- As for "Help" check: see comment at similar line in 'dialog-drag.lua'.
    if focused and dlg.text ~= T"Help" then
      focused:focus()
    end

  end)

end

return M
