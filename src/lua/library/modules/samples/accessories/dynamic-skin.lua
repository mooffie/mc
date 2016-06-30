--[[

Dynamic skin switcher.

This module lets you change the skin automatically according to various
criteria:

  * The directory you're in.
  * Whether the panel is panelized, or filtered.
  * Whether the directory is on a remote host.
  * Whether you're inside an archive.
  * Whether it's a read-only directory.
  * The status of a git repository.
  * etc. etc.

Rationale

Sometimes you want a very visual indication to remind you of your state.
E.g., you don't want to forget that you're browsing a mount of your old
hard-disk and not the real live one.

Installation

    local dynskin = require('samples.accessories.dynamic-skin')

    --
    -- Then describe, with regular expressions, the directories you want
    -- assigned a different skin:
    --
    dynskin.rules:insert { condition = '^/mnt/backup', skin = 'dark' }
    dynskin.rules:insert { condition = '/\\.git(/|$)', skin = 'modarcon16' }

    --
    -- 'condition' may also be a function that tests the panel. Here's one
    -- that tests for a panelized or filtered panel:
    --
    dynskin.rules:insert { condition = function(pnl) return pnl.panelized or pnl.filter end, skin = 'nicedark' }

    --
    -- Another example, which tests for non-local filesystem (e.g., archives):
    --
    dynskin.rules:insert { condition = function(pnl) return not pnl.vdir:is_local() end, skin = 'nicedark' }

Note: the order you insert() the rules *does* matter: the *first* rule
matched will be used.

]]


local List = utils.table.List

local user_skin = nil  -- The user skin. See explanation at bottom.

local function get_active_skin()  -- Makes the code easier to read.
  return tty.skin_change(nil)
end

local M = {}

M.rules = List {}

---------------------------------- The crux ----------------------------------

--
-- Finds the first rule matching a panel's state.
--
local function find_rule(pnl)
  for rule in M.rules:iterate() do
    if type(rule.condition) == "function" then
      if rule.condition(pnl) then
        return rule
      end
    else
      -- Assume it's a regex (in its various forms: string, table, or a
      -- compiled regex). If it isn't, a descriptive exception will be raised.
      if pnl.dir:p_find(rule.condition) then
        return rule
      end
    end
  end
end

--
-- Called whenever a panel's state changes. This function is responsible
-- for changing the skin.
--
-- (The name of this function might be misleading slightly as it alludes
-- to one property only).
--
local on_chdir = utils.magic.once('on_chdir__lock', function(pnl)
  local rule = find_rule(pnl)
  if rule then
    tty.skin_change(rule.skin)
  else
    tty.skin_change(user_skin)
  end
end)

---------------------------------- Bindings ----------------------------------
--
-- We bind our on_chdir() to various events that modify a panel.
--

ui.Panel.bind("<<activate>>", on_chdir)   -- When the user switches between panels.

ui.Panel.bind("<<load>>", function(pnl)   -- When the user navigates between directories; When unpanelizing.
  if pnl == ui.Panel.current then  -- Filter out the <<load>> fired for the "other" (inactive) panel.
    --
    -- Because of a bug, described in 'TODO.long', it's unsafe to draw a panel
    -- (something which tty.skin_change() eventually triggers) directly in a
    -- <<panel::load>>. So we postpone this with ui.queue().
    --
    ui.queue(function()
      on_chdir(pnl)
    end)
  end
end)

ui.Panel.bind("<<panelize>>", on_chdir)   -- When panelizing.

--
-- While we can't currently think of examples, the user might wish to
-- change the skin when various other things happen to a panel.
--
-- Since we don't have events fired for every thing, we use a trick:
-- whenever a dialog closes, there's a potential for whatever "thing" to
-- have happened, so we trigger our on_chdir there.
--
-- (We borrowed this trick from the "Restore selection" module.)
--
-- @todo: Remove this code if we can't come up with an example
--        demonstrating its usefulness.
--
ui.Dialog.bind('<<close>>', function(dlg)

  if dlg.text == T'Appearance' then
    -- There's one exception:
    -- When the user exits the skin selector dialog, let him enjoy
    -- the skin he's just picked. Don't yet revert it to the one we're
    -- supposed to show. Maybe he can't stand that skin.
    return
  end

  -- We want to see the changes done *after* the dialog gets closed,
  -- so we postpone ourselves.
  ui.queue(function()
    -- We aren't interested in dialogs closed in the editor/viewer, only in the
    -- filemanager, so we use `current_widget('Panel')` instead of `ui.Panel.current`.
    local pnl = ui.current_widget('Panel')
    if pnl then
      on_chdir(pnl)
    end
  end)

end)

------------------------------------------------------------------------------
--
-- Figure out the "user skin". That is, the skin the user picked in the
-- "Appearance" dialog.
--
-- This is not a very trivial task, because the user may change his skin as
-- he works. So we track the user whenever he picks a skin. But we
-- ourselves, in on_chdir(), pick a skin too, so we have to exclude our own
-- intervention: we do this with a lock.

local on_user_changes_skin = utils.magic.once('on_chdir__lock', function()
  user_skin = get_active_skin()
end)

event.bind('ui::skin-change', on_user_changes_skin)
event.bind('ui::ready', on_user_changes_skin)  -- when MC starts.

-- @todo:
--
-- What to do when the user restarts Lua?
--
-- * We shouldn't do `user_skin = get_active_skin()` because the active skin
-- may be one we ourselves set.
--
-- * We shouldn't do `user_skin = "default"` because this effectively turns
-- off the user's preferred skin.
--
-- * We shouldn't leave it 'nil' as this would mean that skins we set ourselves
-- won't be switched out of.
--
-- Perhaps we should read the setting from MC's .ini file. But we don't have a
-- function for this yet.
--
-- In the meantime we do `user_skin = get_active_skin()` when we know it's
-- not us who activated the skin. We set it to "default" otherwise.
--
event.bind('core::after-restart', function()
  if ui.Panel.current and (not find_rule(ui.Panel.current)) then
    user_skin = get_active_skin()
  else
    user_skin = "default"
  end
end)

function M.debug()
  -- Show us what this module thinks is the user skin.
  ui.Panel.bind_if_commandline_empty('=', function()
    alert(user_skin)
  end)
end

------------------------------------------------------------------------------

return M
