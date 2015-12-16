--[[

Size calculator.

It shows you the total size of the selected files (or of the current
file) in various units.

Installation:

    -- Note: it's an upper S, not lower s. Lower s triggers "Symbolic link".
    ui.Panel.bind('C-x S', function(pnl)
      require('samples.accessories.size-calculator').run(pnl)
    end)

Why is it useful?

Imagine you have a bunch of files you want to copy to a media that has
1,819 MiB free space. So you mark all the files you want to copy and MC
tells you "1,857,302K bytes in 4 files". Will it fit in 1,819 MiB? You
don't know. Thankfully, Size Calculator will tell you that your 4 files
are "1,813.77 MiB". Hurrey! They will fit!

Related ticket:

    http://www.midnight-commander.org/ticket/2374
    "show exactly files and free space sizes"

]]

local M = {}

-- Sums the sizes of all the marked files (or of the current
-- file if none is marked).
local function compute_total(pnl)
  local total = 0
  local use_current = not pnl.marked

  for fname, stat, is_marked, is_current in pnl:files() do
    if is_marked or (is_current and use_current) then
      total = total + stat.size
    end
  end

  return total
end

-- Shows the dialog.
--
-- Possible 'opts': use_coma, add_other_panel.
--
local function show_dialog(total, opts)

  local fmt = function(n) return opts.use_comma and locale.format_number(n) or n end
  local r = utils.text.round

  local dlg = ui.Dialog(T"Size calculator")

  dlg:add(ui.HBox{expandx=true}:add(
    ui.Space{expandx=true},  -- The purpose of the two expanded Space widgets at
                             -- both sides is to horizontally center the groupboxes.
    ui.Groupbox(T"1024 based"):add(
      ui.Label(T"%s bytes":format(fmt(total))),
      ui.Label(T"%s KiB":format(fmt(math.ceil(total / 1024)))),
      ui.Label(T"%s MiB":format(fmt(r(total / 1024 / 1024, 2)))),
      ui.Label(T"%s GiB":format(fmt(r(total / 1024 / 1024 / 1024, 2))))
    ),
    ui.Groupbox(T"1000 based (SI)"):add(
      ui.Label(T"%s bytes":format(fmt(total))),
      ui.Label(T"%s kB":format(fmt(math.ceil(total / 1000)))),  -- "kB" is no spelling mistake.
      ui.Label(T"%s MB":format(fmt(r(total / 1000 / 1000, 2)))),
      ui.Label(T"%s GB":format(fmt(r(total / 1000 / 1000 / 1000, 2))))
    ),
    ui.Space{expandx=true}
  ))

  local again = false

  local use_comma_chk = ui.Checkbox{T"Use digits &separator", checked = opts.use_comma}
  use_comma_chk.on_change = function(self)
    opts.use_comma = self.checked
    again = true
    dlg:close()
  end

  local add_other_panel_chk = ui.Checkbox{T"Add selected files of &inactive panel", checked = opts.add_other_panel}
  add_other_panel_chk.on_change = function(self)
    opts.add_other_panel = self.checked
    again = true
    dlg:close()
  end

  dlg:add(use_comma_chk)
  dlg:add(add_other_panel_chk)
  dlg:add(ui.Buttons():add(ui.OkButton()))

  dlg:run()

  return again
end

function M.run(pnl)

  local again = true
  local opts = { use_comma = true, add_other_panel = false }

  while again do

    local total = compute_total(pnl)

    if opts.add_other_panel then
      local other_panel = (pnl == ui.Panel.current and ui.Panel.other or ui.Panel.current)
      if other_panel and other_panel.marked then
        total = total + compute_total(other_panel)
      end
    end

    again = show_dialog(total, opts)

  end

end

return M
