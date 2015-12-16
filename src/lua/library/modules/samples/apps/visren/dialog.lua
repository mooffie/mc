
local append = table.insert
local search = require('samples.apps.visren.search')
require("samples.apps.visren.diffview") -- Installs ui.Diffview
require('samples.ui.extlabel') -- Installs ui.ExtLabel


local function run_dialog(world, opts)

  local renamer = require("samples.apps.visren.renamer").new(world)

  local dlg = ui.Dialog(opts.title or T"Visual Rename")

  local ipt = ui.Input{"", history="visren pattern", expandx=true}
  local template = ui.Input{"", history="visren replacement", expandx=true}
  local match_type = ui.Radios{items=search.get_menu()}
  local global = ui.Checkbox{T"Glob&al", checked=opts.global}
  local ignore_case = ui.Checkbox{T"&Ignore case"}
  local status = ui.ExtLabel{"Status:", expandx=true}

  local diffview = ui.Diffview {
    cols = 40, rows = 4,  -- Minimum dimensions.
    expandx = true, expandy = true,
    provider = renamer,  -- Note this!
  }

  --------------------------- on_change handlers ---------------------------

  -- As a convenience, pick a useful template for the user: "\0" when
  -- using PCRE/Lua.
  local function pick_default_template()
    local mt = match_type.value
    if mt == "pcre" or mt == "lua" then
      if template.text == "" then
        template.text = "\\0"
      end
    else
      -- We're switching to "glob". Clear the regex template.
      if template.text == "\\0" then
        template.text = ""
      end
    end
  end

  pick_default_template()  -- initialization

  local style = {
    clashes = tty.style('error._default_'),
    invalid_pattern = tty.style('dialog.dhotfocus'),  -- there doesn't seem to be anything much better.
  }

  -- Call this when any search parameter changes.
  local function pattern_updated()
    renamer:set_env(match_type.value, world:is_utf8(), not ignore_case.checked, global.checked)
    renamer:set_template(template.text)
    local ok, errmsg = renamer:set_pattern(ipt.text)
    if not ok then
      status.text = T"Pattern error: %s":format(errmsg)
      status.style = style.invalid_pattern
    else
      status.text = (opts.status or T"%d/%d files matching; %d clashes"):format(renamer:get_status())
      status.style = renamer:has_clashes() and style.clashes
    end
    diffview:ensure_visibility()
    diffview:redraw()
  end

  pattern_updated()  -- initialization

  match_type.on_change = function()
    pick_default_template()
    global.enabled = (match_type.value ~= "glob")
    ignore_case.enabled = (match_type.value ~= "lua")
    pattern_updated()
  end

  global.on_change = function(self)
    pattern_updated()
  end
  ignore_case.on_change = function(self)
    pattern_updated()
  end
  ipt.on_change = function(self)
    pattern_updated()
  end

  template.on_change = function(self)
    pattern_updated()
  end

  -------------------------- Scrolling the diffview ------------------------

  local K = utils.magic.memoize(tty.keyname_to_keycode)

  local navigation = {
    [K'pgup'] = diffview.page_up,
    [K'pgdn'] = diffview.page_down,
    [K'C-left'] = diffview.char_left,
    [K'C-right'] = diffview.char_right,
    [K'C-up'] = diffview.line_up,
    [K'C-down'] = diffview.line_down,
  }

  dlg.on_key = function(self, keycode)
    if navigation[keycode] then
      navigation[keycode](diffview)
      diffview:redraw()
      return true
    end
  end

  --------------------------------- Help -----------------------------------

  dlg.on_help = function()
    local help = assert(require "utils.path".module_path("samples.apps.visren", "README.md"))
    mc.view(help)
  end

  local btn_help = ui.Button{T"H&elp", on_click = dlg.on_help}

  ------------------------------ Misc buttons ------------------------------

  local btn_side_by_side = ui.Checkbox{T"&Side by side", on_change = function(self)
    diffview.side_by_side = self.checked
  end}
  btn_side_by_side.checked = opts.side_by_side
  btn_side_by_side:on_change()

  -- We put our code on the button, not after dlg:run(), because the dialog may be modaless.
  local btn_ok = ui.OkButton {on_click = function()
    dlg:close()
    -- The postponement is done to make our code run when the dialog is no longer on screen.
    ui.queue(function()
      renamer:do_rename()
    end)
  end}

  --------------------------------- Layout ---------------------------------

  dlg:add(
    ui.HBox({expandx = true}):add(
      ui.VBox():add(
        ui.Label(T"Pattern:"),
        ui.Label(T"Replace with:")
      ),
      ui.VBox({expandx = true}):add(
        ipt,
        template,
        ui.HBox():add(
          global, ignore_case
        )
      ),
      ui.Groupbox({T"Pattern type", expandx = false}):add(match_type)
    )
  )

  dlg:add(status)
  dlg:add(diffview)

  dlg:add(ui.HBox{expandx=true}:add(
    btn_help,
    ui.Space {expandx=true},
    btn_side_by_side,
    ui.Space(1)
  ))

  ------------------------------ Buttons bar -------------------------------

  local btns_array = { btn_ok, ui.CancelButton() }

  -- Give the world a chance to add buttons of its own.
  if world.alter_buttons then
    world:alter_buttons(btns_array, renamer)
  end

  local btns = ui.Buttons()
  for _, b in ipairs(btns_array) do
    btns:add(b)
  end
  dlg:add(btns)

  --------------------------------------------------------------------------

  if opts.maximize then
    dlg.modal = false
    dlg:set_dimensions(nil, nil, tty.get_cols(), tty.get_rows() - 2)
  end

  dlg:run()

end

return {
  run_dialog = run_dialog,
}
