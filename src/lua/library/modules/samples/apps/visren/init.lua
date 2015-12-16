--[[

Visual Rename / Replace

Renames files (panel) and replaces strings (editor).

Installation:

    ui.Panel.bind('C-x r', function()
      require('samples.apps.visren').run()
    end)
    ui.Editbox.bind('C-x r', function()
      require('samples.apps.visren').run()
    end)

    --
    -- The Visual Rename app can also function as a panelizer, as
    -- it has a "Panelize" button.
    --
    -- We can make this panelizer even easier to use by providing
    -- an `easy_panelize=true` flag, as shown here. This makes the
    -- "Panelize" button the default one (that is, you just press
    -- ENTER to apply), and it also means that you don't need to
    -- mark files in advance.
    --
    ui.Panel.bind('C-p', function()
      require('samples.apps.visren').run{easy_panelize=true}
    end)

You may pass options to the run() function:

    ui.Editbox.bind('C-x r', function()
      require('samples.apps.visren').run{maximize=false}
    end)

You may plug in your own replacement code. See "modifiers" in the
online help (README.md).

]]

local run_dialog = require('samples.apps.visren.dialog').run_dialog

local function run(opts)

  opts = opts or {}

  local function setopt(name, val)
    -- Don't override user-supplied options.
    if opts[name] == nil then
      opts[name] = val
    end
  end

  local world

  if ui.current_widget("Panel") then
    setopt('side_by_side', true)
    local pnl = ui.current_widget()
    if not opts.easy_panelize then
      if not pnl.marked and pnl.current == ".." then
        abort(T"First mark the files, or stand on the file, you want to rename.")
      end
    end
    world = require("samples.apps.visren.worlds.panelworld").new(pnl, opts)
  elseif ui.current_widget("Editbox") then
    setopt('title', T"Visual Replace")
    setopt('status', T"%d/%d lines matching")
    setopt('global', true)
    world = require("samples.apps.visren.worlds.editboxworld").new(ui.current_widget(), opts)
  else
    abort(E"I need a panel or editbox!")
  end

  setopt('maximize', true)

  run_dialog(world, opts)
end

return {
  run = run,
}
