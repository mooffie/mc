--[[

Docker.

This module lets you inject widgets to the filemanager dialog. These
widgets are aligned like "taskbars" (aka "docks").

Most notably, this module is used by the "ticker" module.

Usage:

    local docker = require('samples.libs.docker')

    docker.register_widget('north', function()
      return ui.Label("hi!")
    end)

(You'll probably want to make the constructor function store the
widget in a variable somewhere so you can access it later.)

Only 'north' and 'south' are currently recognized as regions.

The only public functions of this module are register_widget(),
refresh(), and trigger_layout().

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
}

--
-- Registers a widget.
--
-- You should provide a "constructor" function that returns (possibly creates,
-- too) the widget. The reason register_widget() doesn't accept a widget
-- directly is to make your life easier: you may call register_widget() from
-- the top-level or in some other place where the UI isn't yet ready. The
-- constructor function is guaranteed to be called when the UI is ready.
--
function M.register_widget(region, constructor)
  append(injects[region], {
    w = nil,  -- (here for the sake of documentation.)
    constructor = constructor
  })
end

local function get_injects(region)
  local list = {}
  for _, inf in ipairs(injects[region]) do
    inf.w = inf.w or inf.constructor()
    append(list, inf.w)
  end
  return list
end

----------------------------------- Utils ------------------------------------

--
-- Returns the filemanager dialog.
--
local function filemanager_dlg()
  local pnl = ui.Panel.current or ui.Panel.other
  return pnl and pnl.dialog
end

--
-- Not used. For debugging.
--
function M.see()
  devel.view(
    utils.table.new(filemanager_dlg().mapped_children):map(function(w)
      return {
        w.widget_type,
        w.x, w.y, w.cols, w.rows,
      }
    end)
  )
end

----------------------------------- Layout -----------------------------------

--
-- Arranges the panels so that there's room for the regions.
--
-- Returns the 'y' coordinates of the regions.
--
local function make_room(dlg, space)

  local function is_panel(w)
    return (w.widget_type == "Panel" or w.widget_type == "Widget")  -- "Widget" when it's a treeview, quickview etc.
             and w.rows > 1  -- Otherwise it would be the menubar/keybar/whatever.
  end

  local function margin_bottom(w)  -- Returns distance to screen edge.
    return tty.get_rows() - w.y - w.rows
  end

  local MIN_PANEL_ROWS = 3

  local start_y = {}

  for w in dlg:gmatch() do

    if is_panel(w)
        and (w.y == 0 or w.y == 1)  -- Else it's most probably the "Below" panel (when splitting horizontally).
    then
      start_y.north = w.y
      w.y = w.y + space.north
      w.rows = math.max(w.rows - space.north, MIN_PANEL_ROWS)
    end

    if is_panel(w)
        and margin_bottom(w) < 5  -- Else it's most probably the "Above" panel (when splitting horizontally).
    then
      start_y.south = w.y + w.rows - space.south
      w.rows = math.max(w.rows - space.south, MIN_PANEL_ROWS)
    end

  end

  return start_y

end

local function sum_property(list, prop)
  local sum = 0
  for _, obj in ipairs(list) do
    sum = sum + obj[prop]
  end
  return sum
end

--
-- Called after MC has positioned all the widgets (the panels, the commandline, etc.).
--
-- Here we make room for our injects and position them.
--
local function layout(dlg)

  local start_y = make_room(dlg, {
    north = sum_property(get_injects 'north', 'rows'),
    south = sum_property(get_injects 'south', 'rows'),
  })

  local function unfocus()
    local pnl = ui.Panel.current or ui.Panel.other
    pnl:focus()
  end

  local function map_region(region)
    local y = start_y[region]
    if y then  -- In the future we may have regions that can't be satisfied.
      for _, w in ipairs(get_injects(region)) do
        w.y = y
        w.x = 0
        w.cols = tty.get_cols()
        y = y + w.rows

        if not w.dialog then
          dlg:map_widget(w)
          unfocus()  -- We normally don't want this widget to get the focus.
        end
      end
    end
  end

  map_region('north')
  map_region('south')

end

ui.Dialog.bind('<<layout>>', function(dlg)
  if dlg == filemanager_dlg() then  -- We deal only with the filemanager dialog.
    --tty.beep()  -- debugging.
    layout(dlg)
  end
end)

--------------------------------- Refreshing ---------------------------------

--
-- Call this to update the display after you change the
-- appearance of a widget.
--
function M.refresh()

  local dlg = filemanager_dlg()

  if dlg then

    if dlg.state ~= 'active' then
      -- The editor or viewer (or some such modaless dialog) is active and
      -- obscures us. Do nothing: don't waste CPU cycles on updating the screen.
    else
      if not ui.current_widget("Panel") then
        -- If a modal dialog is on top (e.g., "Directory hotlist"), or if the
        -- menu is active, we don't want to paint over them, so we redraw the
        -- entire screen (which goes from bottom to top).
        tty.redraw()
        tty.refresh()
      else
        -- Else we just refresh the screen (after repositioning the cursor).
        dlg:redraw_cursor()
        tty.refresh()
      end
    end

  end

end

--
-- Usually you call register_widget() at the top-level, and right afterwards
-- the UI initializes and the layouting is done. However, if you call
-- register_widget() not a the top level you need to call trigger_layout().
--
function M.trigger_layout()
  local dlg = filemanager_dlg()
  if dlg then
    dlg:set_dimensions(dlg.x, dlg.y, dlg.cols, dlg.rows, true)  -- Note the 'true'!
  end
end

---------------------------- Lua restart support -----------------------------

--
-- Note: We could instead merely "remove" the widgets, not "destroy" them, but
-- there's currently no dlg:unmap_widget() method (see comment in ui.c).
--
local function destroy_injects()

  local dlg = filemanager_dlg()

  local function destroy_region(region)
    for _, w in ipairs(get_injects(region)) do
      dlg:_del_widget(w)
    end
  end

  if dlg then
    destroy_region('north')
    destroy_region('south')
  end

end

event.bind('core::before-restart', function()
  -- We restore the filemanager original layout because the user
  -- may not re-load this module again.
  destroy_injects()
  layout = function() end  -- a hackish way to turn off our layouter.
  M.trigger_layout()
end)

event.bind('core::after-restart', function()
  M.trigger_layout()
  tty.refresh()
end)

------------------------------------------------------------------------------

return M
