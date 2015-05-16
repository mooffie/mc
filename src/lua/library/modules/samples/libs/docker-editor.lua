--[[

Docker, for the editor.

This is similar in principle to the filemanager's docker (see docker.lua),
except that it works for the editor.

The reason the two dockers don't currently share code is because the
fundamental differences between the two: whereas there's a single filemanager
dialog, there may be multiple editor dialogs (and each may have several Editbox
widgets!).

We still need to study what our users (=programmers) would expect of this
docker. Till we learn more about our users' expectations, it won't be wise to
try to unify the two dockers.

---

Note: this docker also supports the 'west' and 'east' regions.

Note: the handling of Editboxes that aren't "fullscreen" is yet to be worked on.

]]

local append = table.insert

local M = {}

------------------------------------ Data ------------------------------------

-- Holds all the injected widgets. Populated by register_widget().
local injects = {
  north = {
  },
  south = {
  },
  east = {
  },
  west = {
  },
}

--
-- Registers a widget.
--
-- See documentation at docker.lua:register_widget().
--
function M.register_widget(region, constructor)
  append(injects[region], {
    ws = {},  -- "ws" is the plural of "w".
    constructor = constructor
  })
end

--
-- You'll notice that, in contrast to docket.lua:get_injects(), here we receive
-- a dialog as arguments, because every dialog has its own widgets (=injects).
--
local function get_injects(dlg, region)
  local list = {}
  for _, inf in ipairs(injects[region]) do
    inf.ws[dlg] = inf.ws[dlg] or inf.constructor(dlg)
    if inf.ws[dlg] then  -- the constructor may choose not to create one.
      append(list, inf.ws[dlg])
    end
  end
  return list
end

----------------------------------- Utils ------------------------------------

--
-- Iterates over all the injects.
--
local function iter(fn, include_destroyed)
  for rgn_name, region in pairs(injects) do
    for _, inf in ipairs(region) do
      for dlg, w in pairs(inf.ws) do
        local visit = include_destroyed or (dlg:is_alive() and w:is_alive())
        if visit then
          fn(dlg, w, rgn_name, inf.ws)
        end
      end
    end
  end
end

--
-- Not used. For debugging only.
--
function M.see()
  local t = {}
  iter(function(dlg, w, region)
    append(t, { dlg.widget_type, dlg:is_alive(), w.widget_type, w:is_alive(), region })
  end, true)
  devel.view(t)
end

--keymap.bind('C-y', M.see)

----------------------------------- Layout -----------------------------------

local function sum_property(list, prop)
  local sum = 0
  for _, obj in ipairs(list) do
    sum = sum + obj[prop]
  end
  return sum
end

--
-- Arranges the editor dialog so that there's room for the regions.
--
-- Returns the regions' coordinates.
--
local function make_room(dlg, space)

  local center_cols = dlg.cols - space.west - space.east
  local center_rows = dlg.rows - 2 - space.north - space.south

  for w in dlg:gmatch('Editbox') do

    -- @todo: We should figure out what to do with Editboxes that aren't
    -- "fullscreen".
    w.x = space.west
    w.y = space.north + 1
    w.rows = center_rows
    w.cols = center_cols

  end

  local drawers = {
    north = { x = 0, y = 1, cols = dlg.cols },
    south = { x = 0, y = dlg.rows - 1 - space.south, cols = dlg.cols },
    west = { x = 0, y = space.north + 1, rows = center_rows },
    east = { x = dlg.cols - space.east, y = space.north + 1, rows = center_rows },
  }

  return drawers

end

--
-- Adds our injects to the editor dialog.
--
-- First we make room for them, then we position them.
--
local function layout(dlg)

  local drawers = make_room(dlg, {
    north = sum_property(get_injects(dlg, 'north'), 'rows'),
    south = sum_property(get_injects(dlg, 'south'), 'rows'),
    east = sum_property(get_injects(dlg, 'east'), 'cols'),
    west = sum_property(get_injects(dlg, 'west'), 'cols'),
  })

  --
  -- The following line is critical.
  --
  -- Starting with MC 4.8.12 (commit bf474e), the editor (and viewer) have a
  -- NULL 'color' table (WDialog.color). Therefore, if you inject builtin
  -- widgets (ui.Label, etc.) it will segfault MC because such widgets look up
  -- the dialog's 'color' table.
  --
  -- The following line solves the problem (as it sets WDialog.color).
  --
  dlg.colorset = "normal"

  local function unfocus()
    if dlg:find('Editbox') then
      dlg:find('Editbox'):focus()
    end
  end

  local function map_region(region, vertical)
    local d = drawers[region]
    if d then  -- In the future we may have regions that can't be satisfied.
      local y, x = d.y, d.x
      for _, w in ipairs(get_injects(dlg, region)) do

        if vertical then
          w.y = y
          w.x = d.x
          w.cols = d.cols
          y = y + w.rows
        else
          w.y = d.y
          w.x = x
          w.rows = d.rows
          x = x + w.cols
        end

        if not w.dialog then
          dlg:map_widget(w)
          unfocus()  -- We normally don't want this widget to get the focus.
        end

      end
    end
  end

  map_region('north', true)
  map_region('south', true)
  map_region('west')
  map_region('east')

end

event.bind('editor::layout', function(dlg)
  --tty.beep()  -- debugging.
  layout(dlg)
end)

--------------------------------- Refreshing ---------------------------------

--
-- See comment at docker.lua:trigger_layout().
--
function M.trigger_layout()
  for _, dlg in ipairs(ui.Dialog.screens) do
    if dlg:find('Editbox') then  -- Yes, this is an editor.
      dlg:set_dimensions(dlg.x, dlg.y, dlg.cols, dlg.rows, true)  -- Note the 'true'!
    end
  end
  tty.redraw()
end

-- @todo: we should have M.refresh() too (see docker.lua:refresh()).

------------------------------------- GC -------------------------------------

-- Every few seconds we remove destroyed widgets. These are actually the
-- Lua wrappers (Lua tables) around C widgets. We want them to be GC too. It's
-- not critical to do this, but we should keep things tidy.

local function clean()
  iter(function(dlg, w, region, ws)
    if not (dlg:is_alive() and w:is_alive()) then
      ws[dlg] = nil  -- It's safe in Lua to clear fields while traversing the table.
    end
  end, true)  -- Note this 'true'.
end

timer.set_interval(clean, 5*1000)

---------------------------- Lua restart support -----------------------------

event.bind('core::before-restart', function()

  -- We restore the editor dialogs' original layout because the user
  -- may not re-load this module again.

  iter(function(dlg, w, region)
    dlg:_del_widget(w)
    injects[region] = {}
  end)

  M.trigger_layout()

end)

event.bind('core::after-restart', function()

  -- Re-inject our widgets to all the already open editors.
  M.trigger_layout()

  -- Sometimes the panels obscures the editor upon restart. Perhaps there's
  -- a module running after us that triggers a panel redraw in its
  -- ::after-restart? In any case, the following delayed code solves this.
  timer.set_timeout(function()
    tty.redraw()
    tty.refresh()
  end, 0)

end)

------------------------------------------------------------------------------

return M
