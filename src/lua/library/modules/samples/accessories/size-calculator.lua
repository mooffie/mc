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
tells you "1,857,302K bytes in 12 files". Will it fit in 1,819 MiB? You
don't know. Thankfully, Size Calculator will tell you that your 12 files
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
local function show_dialog(total, use_comma)

  local fmt = function(n) return use_comma and locale.format_number(n) or n end
  local r = utils.text.round

  local dlg = ui.Dialog(T"Size calculator")

  dlg:add(ui.HBox():add(
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
    )
  ))

  local use_comma_chk = ui.Checkbox{T"Use &comma separator", checked = use_comma}
  local again = false

  use_comma_chk.on_change = function()
    again = true
    dlg:close()
  end

  dlg:add(use_comma_chk)
  dlg:add(ui.Buttons():add(ui.OkButton()))

  dlg:run()

  return again, use_comma_chk.checked
end

function M.run(pnl)
  local total = compute_total(pnl)

  local again = true
  local use_comma = true

  while again do
    again, use_comma = show_dialog(total, use_comma)
  end
end

return M
