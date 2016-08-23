--[[

The tabs module.

See README.md.

]]

local docker = require('samples.libs.docker')
require('samples.accessories.tabs.tbuttonbar')
require('samples.accessories.snapshots')  -- Implements the 'snapshot_panelized_list' panel property.

local M = {

  -- Settings to save.
  fields = {
    -- Note: The order is important. See comment in set_panel_settings().
    'dir', 'sort_field', 'sort_reverse', 'list_type',
    'custom_format', 'custom_mini_status', 'custom_mini_status_format',
    'filter', 'snapshot_panelized_list',
    -- 'current'/'marked' come after panelization because the files
    -- possibly isn't in the list prior to that.
    'current', 'marked',
  },

  -- Either "north" or "south".
  region = "north",

  -- The buttonsbar style.
  style = {
    normal = 'dialog._default_',
    selected = 'error._default_',  -- Typically red. It makes the button stand out more.
  },
}

local bar = nil  -- The buttonsbar.

----------------------------------- Utils ------------------------------------

local function get_selected_button()
  return bar.selected_button
end

local function get_current_tab()
  return get_selected_button().tab
end

-- Answers: Do we have just a single tab?
local function has_single_tab()
  return #bar.btns <= 3  -- as there are also the 'close tab' and 'new tab' buttons.
end

------------------------------------------------------------------------------

--
-- Restores a panel's properties from a bag.
--
local function set_panel_settings(pnl, settings)

  do
    -- Tell user of directories that no longer exist, etc.
    local ok, errmsg = fs.nonvfs_access(settings.dir, 'x')
    if not ok then
      alert(errmsg)
    end
  end

  -- Note: the order in which we set the fields is important: We can't set
  -- 'current' before 'dir', or 'custom_mini_status_format' before 'list_type'.
  for _, name in ipairs(M.fields) do
    pnl[name] = settings[name]
  end

end

--
-- Records a panel's properties into a bag.
--
local function get_panel_settings(pnl)
  local settings = {}
  for _, name in ipairs(M.fields) do
    settings[name] = pnl[name]
  end
  return settings
end

--
-- Creates a tab.
--
-- A tab is simply a structure recording the properties of both
-- panels; it's of the form:
--
--    {
--      left = {
--        dir = "/home/mooffie",
--        list_type = "full",
--        sort_field = "name",
--        ...
--      },
--      right = {
--        dir = "/home/mooffie/mc/src/lua",
--        ...
--      },
--      current = "left",
--    }
--
local function new_tab()
  local tab = {}
  if ui.Panel.left then
    tab.left = get_panel_settings(ui.Panel.left)
  end
  if ui.Panel.right then
    tab.right = get_panel_settings(ui.Panel.right)
  end
  tab.current = (ui.Panel.current == ui.Panel.left) and 'left' or 'right'
  return tab
end

---------------------------- Update/restore a tab ----------------------------

--
-- "Updating" a tab copies the panels' properties into it.
--
-- "Restoring" a tab does the opposite: it sets the panels' properties
-- to the ones recorded in the tab.
--

--
-- Call this right before you switch to another tab.
--
local function tab_update_current()
  local tab = get_current_tab()
  local props = new_tab()
  tab.left = props.left
  tab.right = props.right
  tab.current = props.current
end

local function _tab_restore(tab)
  if ui.Panel.left and tab.left then
    set_panel_settings(ui.Panel.left, tab.left)
  end
  if ui.Panel.right and tab.right then
    set_panel_settings(ui.Panel.right, tab.right)
  end
  if ui.Panel[tab.current] then
    ui.Panel[tab.current]:focus()
  end
end

--
-- Call this after you switch to a tab.
--
local function tab_restore_current()
  _tab_restore(get_current_tab())
end

------------------------------- Mouse support --------------------------------

local function on_tab_click(btn, count)
  if count == "double" then
    -- double click.
    M.rename_tab()
  else
    -- single click.
    if get_selected_button() ~= btn then  -- We don't need to do this check. But if the computer is slow, double clicking will take too much time, and "double" won't be detected.
      tab_update_current()
      bar.selected_button = btn
      tab_restore_current()
    end
  end
end

function M.rename_tab(optional_label)
  local btn = get_selected_button()  -- Note: we don't want to receive 'btn' as argument because this module-function should be usable from outside.
  local label = optional_label or prompts.input(T"Enter new tab name:", btn.label, "", "tab-names")
  if label then
    btn.label = label
    bar:redraw()
  end
end

--------------------------- Creating/deleting tabs ---------------------------

--
-- Creates a label that no other button bears.
--
-- It simply adds a running number to the end of the label
-- you give it till it's unique. E.g.: given "tab", returns "tab2".
--
local function create_unique_label(label)
  local base = label:match '(.-)%d*$'  -- removes any existing number.
  for counter = 2, 1000 do
    local new_label = base .. counter
    local exists = bar.btns:find(function(b) return b.label == new_label end)
    if not exists then
      return new_label
    end
  end
end

function M.create_tab(optional_label)

  -- If none given, we create a label based on the curernt tab.
  local label = optional_label or create_unique_label(get_selected_button().label)

  if get_current_tab() then  -- When we're called from init_buttonbar(), there isn't even a single tab.
    tab_update_current()
  end

  local tab = new_tab()

  local btn = {
    tab = tab,
    selectable = true,
    label = label,
    on_click = on_tab_click,
  }

  bar:add_button(btn, -1)
  bar.selected_button = btn

end

function M.close_tab()
  abortive(not has_single_tab(), T"You cannot close the only tab.")

  local btn = get_selected_button()
  bar:delete_button(btn)
  if not get_selected_button().selectable then
    -- We've deleted the right-most tab. Select the previous one.
    bar:select_prior()
  end
  tab_restore_current()
end

--------------------------------- Navigation ---------------------------------

function M.tab_left()
  tab_update_current()
  bar:select_prior()
  tab_restore_current()
end

function M.tab_right()
  tab_update_current()
  bar:select_next()
  tab_restore_current()
end

--------------------------------- Debugging ----------------------------------

function M.show_debugging_info()
  devel.view(bar.btns)
end

----------------------------------- Setup ------------------------------------

local function init_buttonbar()

  if not bar then

    bar = ui.TButtonBar{style=M.style}

    bar:add_button {
      label = "x",
      on_click = M.close_tab,
    }
    bar:add_button {
      label = "+",
      on_click = function()
        M.create_tab()
      end,
    }
    M.create_tab(T"tab")  -- We must have at least one tab (it's just easier to program this way).

  end

  return bar

end

local function install()
  docker.register_widget(M.region, function()
    return init_buttonbar()
  end)
end

-- We postpone the installation so the user gets a chance to customize M.region.
ui.queue(function()
  install()
  docker.trigger_layout()
end)

------------------------------------------------------------------------------

return M
