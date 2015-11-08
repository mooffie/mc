--[[

Adds a help button to dialogs that have a help page.

The button appears as "[?]" at the top-right corner of the dialog.

Installation:

    require('samples.accessories.dialog-help-button').install()

Rationalization:

Some dialogs have surprisingly useful help pages. Unfortunately, the user
doesn't have a way to know if a dialog has, or hasn't, a help page. This
module solves the problem by alerting the user with an icon when help is
available.

]]

local M = {
  style = {
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
  }
}

local function style(dlg, name)
  return tty.style((M.style[dlg.colorset] or M.style.normal)[name])
end

local function is_fullscreen(dlg)
  return dlg.x == 0 and dlg.y == 0 and dlg.cols == tty.get_cols() and dlg.rows == tty.get_rows()
end

--
-- A few useless help keys set on some common dialogs.
--
-- They serve no useful purpose and we don't want to mislead the user by
-- showing the help button for them.
--
local bogus_help = {
  ["[Input Line Keys]"] = true,
  ["[QueryBox]"] = true,
  ["[History-query]"] = true,
}

----------------------------- The button widget ------------------------------

local FrameButton = ui.Custom.subclass("FrameButton")

FrameButton.__allowed_properties = {
  symbol = true,
}

function FrameButton:init()
  self.symbol = '*'
  self.cols = 3
end

function FrameButton:on_draw()
  local c = self:get_canvas()
  c:erase()
  c:set_style(style(self.dialog, 'brackets'))
  c:draw_string '[ ]'
  c:set_style(style(self.dialog, 'symbol'))
  c:goto_xy(1, 0)
  c:draw_string(self.symbol)
end

------------------------------------------------------------------------------

function M.install()

  ui.Dialog.bind('<<open>>', function(dlg)

    if is_fullscreen(dlg) or not dlg.help_id or bogus_help[dlg.help_id] then
      return
    end

    -- Remember the focused widget.
    local focused = dlg.current

    local MARGIN = dlg.compact and 0 or 1

    local bor = utils.bit32.bor

    dlg:map_widget(ui.FrameButton {
      symbol = '?',
      x = dlg.cols - MARGIN - 1 - 1 - 3,
      y = MARGIN,
      pos_flags = bor(ui.WPOS_KEEP_RIGHT, ui.WPOS_KEEP_TOP),
      on_click = function(self)
        --
        -- In a perfect world we should simply have done:
        --
        --       self.dialog:command "help"
        --
        -- Unfortunately, this won't work because "help" happens to
        -- to be one of the few commands that fall victim to a certain
        -- MC deficiency that makes :command() oblivious to it. See
        -- tech note at :command()'s source for details.
        --
        -- So instead we use mc.help().
        --

        local dlg = self.dialog  -- We can as well use the outside 'dlg' var.
        if dlg.help_id == "[Help]" then
          -- When the help viewer is already showing we don't open
          -- another one but reuse the existing viewer (we can't do
          -- otherwise anyway, as the viewer uses global variables).
          -- In this case :command() does work because the help viewer
          -- implements it directly.
          dlg:command "help"
        else
          mc.help(dlg.help_id)
        end
      end
    }:fixate())

    --[[

    A failed attempt at a close button.

    dlg:map_widget(ui.FrameButton {
      symbol = tty.skin_get('editor.window-close-char', 'x'),
      x = MARGIN + 1 + 1,
      y = MARGIN,
      on_click = function(self)
        --
        -- We should have done 'self.dialog:command "cancel"' here, but "cancel"
        -- happens to be... you guessed it! one of the few commands that don't
        -- work with :command(). See note about.
        --
        -- ':close()' isn't actually an alternative because ours doesn't do
        -- 'h->ret_value = B_CANCEL' on the C side (as it shouldn't) leading some
        -- dialogs (Copy/Move) to think the user OK'ed the action.
        --
        self.dialog:close()
      end
    }:fixate())

    ]]

    -- Restore the previously focused widget.
    -- As for "Help" check: see comment at similar line in 'dialog-drag.lua'.
    if focused and dlg.text ~= T"Help" then
      focused:focus()
    end

  end)

end

return M
