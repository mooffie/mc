--[[

A "Restore selection" feature.

This module lets you restore selections (the set of marked files) that
were previously active.

How to use

By pressing a key you call up a dialog that displays a stack of
selections remembered for the directory you're in. Choose a selection and
press ENTER to accept it. Press ESC to cancel.

Installation

    require('samples.accessories.restore-selection')
    ui.Panel.bind('C-q', function(pnl)
      require('samples.accessories.restore-selection').run(pnl)
    end)

    --
    -- Or, binding it to the '&' key:
    --

    require('samples.accessories.restore-selection')
    ui.Panel.bind('&', function(pnl)
      if ui.current_widget('Input') and ui.current_widget('Input').text == "" then
        require('samples.accessories.restore-selection').run(pnl)
      else
        return false
      end
    end)

Or, with customization:

    local rstr = require('samples.accessories.restore-selection')
    -- If you want to conserve memory:
    rstr.max_dirs = 4  -- Don't track more than 4 directories.
    rstr.max_selections_per_dir = 3
    ui.Panel.bind(...)  -- As above.

How it works

Wherever the selection is about to change, this module records it.
Actually, this description is not true. The selection is recorded at 3
events:

(1) When a dialog box gets opened. (The assumption is that a command that
    changes the selection might be under way.)

(2) After a dialog box gets closed. (To record the new selection
    potentially resulted from executing some command.)

(3) Before you leave a directory.

]]

require('samples.ui.extlabel')

local List = utils.table.new

local M = {
  -- See comments throughout for the meaning of these two.
  max_dirs = 8,
  max_selections_per_dir = 5,

  -- Set to 'true' if you want to enable some debugging aids.
  DBG = false,
}

----------------------------------- The DB -----------------------------------

--[[

The database is a table storing all the remembered selections. Its structure:

  {
    --
    -- Each directory path is associated with a stack of selections.
    -- At most M.max_dirs directories are stored.
    --
    ["/some/directory"] = {
      --
      -- Each stack holds at most M.max_selections_per_dir selections.
      -- A selection is a list of files plus a 'timestamp' field. The
      -- selection at position #1 is the most recent.
      --
      { "file1.txt", "file2.txt", timestamp=1447940660 },
      { "READEM.md", "pic.png", ..., timestamp=1447940502 },
      { "a.out", timestamp=1447920289 }
    },
    ["/another/directory"] = {
      { "doc.in", "doc.html", "doc.pdf", timestamp=1447940660 },
      ...
    },
    ...
  }

]]

local db = List {}

----------------------------------- Utils ------------------------------------

--
-- Compares two arrays.
--
-- Returns 'true' if equal.
--
local function array_eq(a1, a2)
  if #a1 == #a2 then
    for i = 1, #a1 do
      if a1[i] ~= a2[i] then
        return
      end
    end
    return true
  end
end

------------------------------ DB manipulation -------------------------------

--
-- Records a selection in the database.
--
local function _store_selection(pnl)

  if M.DBG then
    tty.beep()
  end

  local selection = List(pnl.marked)

  --
  -- Store the selection. But only if it's not empty, of course, and ...
  --
  if #selection ~= 0 then

    local stack = db[pnl.dir] or List()

    --
    -- ... and if it isn't equal to the previously stored selection.
    --
    if not array_eq(selection, stack[1] or {}) then

      stack:insert(1, selection)  -- Insert at front.
      selection.timestamp = os.time()

      -- Trim the stack.
      if #stack > M.max_selections_per_dir then
        stack = stack:sub(1, M.max_selections_per_dir)
      end

      db[pnl.dir] = stack  -- In case we've just created it, or sub()'ed it.

      --
      -- Trim the DB.
      --
      -- After we add a new directory to the DB we must ensure it has no more
      -- than M.max_dirs entries.
      --
      if #stack == 1 then
        if db:count() > M.max_dirs then
          -- Remove the directory with the oldest activity.
          local min_dir
          for dir in pairs(db) do
            if (not min_dir) or db[dir][1].timestamp < db[min_dir][1].timestamp then
              min_dir = dir
            end
          end
          db[min_dir] = nil
        end
      end

    end

  end

end

-- Bad code in _store_selection() may raise exception. Since it also gets
-- called at <<Dialog::open>>, the exception box will cause inf recursion.
local store_selection = utils.magic.once(_store_selection)

local function store_selection_maybe(pnl)
  if pnl then
    store_selection(pnl)
  end
end

----------------------------------- The UI -----------------------------------

--
-- Helpers.
--

local function render_selection_title(selection)
  local ago = os.time() - selection.timestamp
  return ago < 2 and
           T"%d files (now)":format(#selection) or
           T"%d files (%s ago)":format(#selection, utils.text.format_interval_tiny(ago))
end

local function render_selection_files(selection, max)
  if #selection <= max then
    return selection:concat("\n")
  else
    return selection:sub(1, max - 1):insert("..."):concat("\n")
  end
end

--
-- Runs the dialog for choosing a selection.
--
function M.run(pnl)

  store_selection(pnl)  -- Make the dialog show also the current selection.

  local stack = db[pnl.dir]

  abortive(stack, T"Sorry, no previous selections are remembered for this folder.")

  local original_selection = pnl.marked

  local dlg = ui.Dialog{T"Restore selection", compact=true, padding=0}

  local lstbx = ui.Listbox{
    items = stack:map(function(selection)
      return { render_selection_title(selection), value=selection }
    end),
    rows=5
  }

  local description = ui.ExtLabel{align="left~", expandx=true, expandy=true}

  function lstbx:on_change()
    local selection = self.value
    pnl.marked = selection
    description.text = render_selection_files(selection, description.rows)
    dlg:redraw()  -- Because the panel painted over us.
  end

  function dlg.on_init()  -- We wait till on_init() so the rows of 'description' are set.
    lstbx:on_change()
  end

  dlg:add(
    lstbx,
    ui.ZLine(" " .. T"Files within:" .. " "),
    description
  )

  if M.DBG then
    dlg:add(
      ui.ZLine(),
      ui.Button{ T"See &DB", on_click = function()
        devel.view(db)
      end}
    )
  end

  ----------------------------- Dialog placement -----------------------------

  -- Try not to obscure the panel. The user would like to see the files
  -- as he browses the selections.
  local x
  if pnl == ui.Panel.left then
    x = tty.get_cols() / 2 + 3
  else
    x = tty.get_cols() / 2 - dlg:preferred_cols() - 3
  end

  -- Make the box 25 rows shy from a whole screen. But show at least 17 rows.
  dlg:set_dimensions(
    math.floor(x),
    nil,  -- Center vertically.
    math.max(23, dlg:preferred_cols()),  -- Optional: Make more room for the frame icons.
    math.min(math.max(17, tty.get_rows() - 25), tty.get_rows())
  )

  ----------------------------------------------------------------------------

  if not dlg:run() then
    pnl.marked = original_selection
  end

end

---------------------------------- Bindings ----------------------------------

--
-- See the rationale for using these 3 events at the help at top.
--

ui.Panel.bind('<<before-chdir>>', function(pnl)
  store_selection(pnl)
end)

ui.Dialog.bind('<<open>>', function()
  store_selection_maybe(ui.Panel.current)
end)

ui.Dialog.bind('<<close>>', function()
  -- We want to see the changes done *after* the dialog gets closed,
  -- so we use a timeout.
  timer.set_timeout(function()
    -- We could have used 'ui.Panel.current' here too, but we don't want to
    -- bother with dialogs closed in the editor/viewer as they probably don't
    -- modify the panel's selection.
    store_selection_maybe(ui.current_widget('Panel'))
  end, 0)
end)

------------------------------------------------------------------------------

return M
