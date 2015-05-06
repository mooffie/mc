--[[

Filter-as-you-type. The name says it all.

(Note: the Visual Rename app has a panelize feature that effectively
provides the same functionality. So you have a choice!)

Installation:

    ui.Panel.bind('C-_', function(pnl)
      require('samples.accessories.filter-as-you-type').run(pnl)
    end)

    -- The example here assigns it to C-/, but you may probably
    -- want to assign it to M-s (or C-s).

Rationalization:

MC has a find-as-you-type feature (C-s, or M-s), but not a filter-as-you-type feature. Here
we fill in this void.

Tips:

* You can use the <up>, <down>, <pgup>, <pgdn>, <ins> keys to move about
  and mark files.

* You can press <esc> to cancel the filtering: your marked
  files will remain so. This is quite a useful feature. Say you have
  1000 files, 10 of which are *.c files and three of which you wish to
  mark. So you call up the filter, type ".c", move about and mark
  your files, and THEN you press <esc> to return to the full view!

* You can use the 'samples.accessories.unfilter' module to easily clear
  the filter (while retaining the marked files).

]]

local M = {

  default_filter = '**', -- '*'
  offs = { x = 0, y = 0 },
  size = 25,

  -- The delay before setting the filter. The keys here are the filesystem
  -- prefixes. "localfs" is for the local filesystem.
  delay = {
    default = 100,
    sh = 1000,  -- For the network filesystem we wait 1 sec before filtering.
  }

}

--
-- Calculates the filtering delay for this panel.
--
-- (You may redefine this function to take into account the number
-- of files in the directory (pnl._get_max_index), which is why this
-- function accepts the whole panel instead of its directory only).
--
function M.calculate_delay(pnl)
  local vfs_prefix = pnl.vdir:last().vfs_prefix or "localfs"
  return M.delay[vfs_prefix] or M.delay.default
end

function M.run(pnl)

  local original_filter = pnl.filter

  abortive(not pnl.panelized, T"I can't filter a panelized listing (that's a limitation of MC).")

  local dlg = ui.Dialog{ T'Filter', compact=true }
  local ipt = ui.Input{ cols=M.size, history='mc.fm.panel-filter' }

  ipt.text = pnl.filter or M.default_filter or '*'

  dlg:add(ipt)

  dlg:set_dimensions(pnl.x + 1 + M.offs.x,
                     pnl.y + pnl.rows - 2 + M.offs.y)

  ------------------------------------------------------------------------------

  --
  -- Smartly position the cursor in the input box.
  --
  -- MC resets the cursor position when the dialog initializes (input.c:input_load_history())
  -- so we do this later, at on_idle.
  --
  dlg.on_idle = function()
    -- If the filter is '**' (or, more generally, '*whatever*'), put the
    -- cursor before the last asterisk so the user can start editing
    -- immediately.
    local last_asterisk_pos = ipt.text:match '.()%*$'
    if last_asterisk_pos then
      ipt.cursor_offs = last_asterisk_pos
      dlg:refresh(true)  -- get rid of the 'inputunchanged' color.
    end
    dlg.on_idle = nil
  end

  local delay = M.calculate_delay(pnl)

  --
  -- The crux!
  --
  ipt.on_change = timer.debounce(function()
    if ipt:is_alive() then  -- because of the delay the dialog may be closed by now.
      pnl.filter = ipt.text
      tty.refresh()  -- It happens that this call isn't needed, because MC already does a refresh when the filter gets set. But we shouldn't rely on this "abnormality".
    end
  end, delay)

  ------------------------------------------------------------------------------

  -- We forward some keys to the panel so the user will be able to
  -- navigate there and mark files.

  local K = utils.magic.memoize(tty.keyname_to_keycode)

  local forward_to_panel = {
    [K'up'] = true,
    [K'down'] = true,
    [K'pgup'] = true,
    [K'pgdn'] = true,
    [K'ins'] = true,
  }

  dlg.on_key = function(self, kcode)
    if forward_to_panel[kcode] then
      pnl:_send_message(ui.MSG_KEY, kcode)
      pnl:redraw()
      dlg:refresh(true)
      return true
    end
    return false
  end

  ------------------------------------------------------------------------------

  if not dlg:run() then
    -- If the user presses ESC, we restore the original filter.
    pnl.filter = original_filter
  end

  if pnl.filter == '**' or pnl.filter == '' then
    pnl.filter = nil
  end

end

------------------------------------------------------------------------------

return M
