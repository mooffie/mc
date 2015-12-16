--[[

Shows a "functions menu" navigational aid for program files.

installation:

Add the following to your startup scripts:

    ui.Editbox.bind('C-\\', function()
      require('samples.editbox.funclist').run()
    end)

]]

--[[

NOTE:

This script was written very early in MC/Lua's life, just as a quick
demonstration, and when regex support wasn't in place. This script
is ought to be rewritten.

]]

local append = table.insert

local M = {}

M.parsers = {

  ['Python Program'] = {
    banner = "^%s*class%s",
    banner_name = '([%w_]+)%s*%(',
    func_begin = "^%s*def%s",
    func_name = '([%w_]+)%s*%(',
  },

  ['C Program'] = {
    banner = "%*%*%*%*%*%*%*%*",
    banner_name = '([%w ]+)',
    func_begin = "^%w.*%(",
    func_name = '([%w_:]+)%s*%(',
    func_end = "^}",
  },

  ['PHP Program'] = {
    banner = "^class%s",
    banner_name = 'class%s+([%w_]+)',
    func_begin = "function",
    func_name = 'function%s+([%w_:]+)%s*%(',
  },

--[[
  ideas for the future:
  jslint can analyze code:
  http://www.jslint.com/lint.html#report
]]

}

M.parsers['C/C++ Program'] = M.parsers['C Program']


local function run()

  local edt = assert(ui.current_widget("Editbox"))

  local funcs = {}
  local current_func = nil
  local cursor_func = nil

  local pats = M.parsers[edt.syntax]

  if not edt.syntax then
    abort(T"This file doesn't have an associated syntax.\nI can't show functions in programs of unknown syntax.")
  end

  if not pats then
    abort(T"I don't know how to show functions in '%s'.\nFeel free to contribute code that'd teach me to.":format(edt.syntax))
  end

  local cursor_line = edt.cursor_line

  --
  -- Step 1: parse the text
  --

  for ln, i in edt:lines() do

    if ln:find(pats.func_begin) then
      local name = ln:match(pats.func_name)
      if name then
        current_func = {
          name = name,
          line_start = i
        }
        append(funcs, current_func)
      end
    end

    if pats.banner and ln:find(pats.banner) then
      local name = ln:match(pats.banner_name)
      if name then
        current_func = {
          name = name,
          line_start = i,
          is_banner = true
        }
        append(funcs, current_func)
      end
    end

    if current_func then
      if i == cursor_line then
        cursor_func = current_func
      end
      -- If there's a bookmark set anywhere inside this function, tag the
      -- function as "having bookmarks".
      if edt:bookmark_exists(i, -1) then
        current_func.bookmarked = true
      end
      if pats.func_end and ln:find(pats.func_end) then
        current_func.line_end = i
      end
    end

  end

  --
  -- Step 2: massage 'funcs' a bit, to make it fit as a Listbox's items.
  --

  for _, func in ipairs(funcs) do

    local title

    if func.is_banner then
      title =  ("%s=======%s======="):format(
        func.bookmarked and "*" or " ",
        func.name
      )
    else
      if pats.func_end then
        title = ("%3d %s%s"):format(
          func.line_end and (func.line_end - func.line_start) or 0,
          func.bookmarked and "*" or " ",
          func.name
        )
      else
        title = ("  %s%s"):format(
          func.bookmarked and "*" or " ",
          func.name
        )
      end
    end

    func[1] = title
    func.value = func.line_start

  end

  --
  -- Step 3: Build the UI.
  --

  if #funcs == 0 then
    abort(T"No functions were found here")
  end

  local dlg = ui.Dialog{T"Function list", compact=true}

  local lst = ui.Listbox{expandy=true}
  lst.items = funcs
  lst.cols = lst:widest_item() + 2 -- "+2" because Listbox uses an extra space on both sides.
  if cursor_func then
    lst.value = cursor_func.line_start
  end

  dlg:add(lst)
  dlg:set_dimensions(tty.get_cols() - dlg:preferred_cols(), edt.y, nil, edt.rows)

  if dlg:run() then
    edt.cursor_line = lst.value
  end

end


return {
  run = run,
}
