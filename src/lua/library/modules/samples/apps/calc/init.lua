--[[

A calculator.

INSTALLATION:

    keymap.bind('C-x c', function()
      require('samples.apps.calc').run()
    end)

  or:

    local calc = require('samples.apps.calc')

    -- Create our own function: a sinus that accepts degrees.
    calc.funcs.dsin = function(x) return math.sin(math.rad(x)) end

    keymap.bind('C-x c', function()
      require('samples.apps.calc').run()
    end)


]]

local append = table.insert

local eval = import_from('samples.apps.calc.eval', { 'eval' })
local tobinary, tointeger, baseconv = import_from('samples.apps.calc.utils', { 'tobinary', 'tointeger', 'baseconv' })

require('samples.ui.extlabel')

local M = {
  style = {
    normal = nil,
    error = 'red, lightgray',
  }
}

-- The layout of the output. The user is free to alter this.

M.output_template__number = [[
!dec Dec
!int int
!hex Hex
!oct Oct
!bin Bin
!ascii Asc]]

M.output_template__string = [[
Str !str
Hex !str_hex
Dec !str_dec]]

-- Extra functions to make available to the end-user. The user may add to this.
M.funcs = {

  b = function(s)
    return baseconv(s, 2, T"Invalid binary number '%s'")
  end,

  d = function(s)
    return baseconv(s, 10, T"Invalid decimal number '%s'")
  end,

  h = function(s)
    return baseconv(s, 16, T"Invalid hexadecimal number '%s'")
  end,

  o = function(s)
    return baseconv(s, 8, T"Invalid octal number '%s'")
  end,

}

-- How to render the output fields. The user may add to this.
M.renderers = {

  dec = function(f, i, addsepf, use_digits_separator)
    return use_digits_separator and locale.format_number(f) or f
  end,

  int = function(f, i)
    return i and i or T'n/a'
  end,

  hex = function(f, i, addsepf)
    return i and addsepf(("%x"):format(i), 4, ' ') or T'n/a'
  end,

  oct = function(f, i)
    return i and ("%o"):format(i) or T'n/a'
  end,

  bin = function(f, i, addsepf)
    return i and addsepf(tobinary(i), 4, ' ') or T'n/a'
  end,

  ascii = function(f, i)
    return i and i >= 0 and i < 128 and string.format('%q', string.char(i)) or T'n/a'
  end,

  -- @todo: add a 'unicode' renderer once we have tty.text_chars().

  str = function(s)
    return devel.pp(s)
  end,

  str_hex = function(s)
    return '"' .. s:gsub('.', function(c) return ("\\x%02X"):format(c:byte()) end) .. '"'
  end,

  str_dec = function(s)
    -- This is not an error: In the C language, the notation "\\<digit>{1,3}"
    -- is in octal base, but in Lua it's decimal. OTOH, Maybe we should invent some
    -- other notation in order not to confuse C programmers.
    return '"' .. s:gsub('.', function(c) return ("\\%03d"):format(c:byte()) end) .. '"'
  end,

  -- @todo: add str_codes, which would support Unicode, once we have tty.text_codes().
}


local style = nil
local function init_styles()
  style = utils.table.map(M.style, tty.style)
end


-- Creates the environment accesible inside the evaluated string.
-- We also "import" all the math and bit32 functions into it so the user
-- won't have to prefix them with "math." and "bit32.".
local function create_env(funcs)
  local env = {}
  setmetatable(env, { __index = _G })
  for fname, fn in pairs(math) do
    env[fname] = fn
  end
  for fname, fn in pairs(bit32 or utils.bit32) do
    env[fname] = fn
  end
  for fname, fn in pairs(funcs) do
    env[fname] = fn
  end
  return env
end


-- Adds a separator every 'count' characters.
local function addsep(s, count, sep)
  return s
          :reverse()
          :gsub(string.rep('.', count), '%0' .. sep)
          :reverse()
end


-- Determines whether a table is "simple enough" to be displayed
-- directly in the output box. It's a matter of opinion. We deem
-- it simple if it only has array keys.
local function is_simple_table(t)
  local max = #t
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k > max then
      return false
    end
  end
  return true
end

local function render_values(values, pp)
  local elts = {}
  for i = 1, values.n do
    append(elts, pp(values[i]))
  end
  return (#elts == 0 and T"<none>" or table.concat(elts, ", "))
end

local function noop(a) return a end

local function display_result(output, values, use_digits_separator)

  output.style = style.normal

  if values.n == 1 and type(values[1]) == "number" then

    local f = values[1]        -- float
    local i = tointeger(f)     -- integer (if available)

    local addsepf = use_digits_separator and addsep or noop

    output.align = "right~"

    output.text = M.output_template__number:gsub('!([%w_]+)', function(name)
      local fn = M.renderers[name]
      if fn then
        return fn(f, i, addsepf, use_digits_separator)
      end
    end)

  elseif values.n == 1 and type(values[1]) == "string" then

    local s = values[1]

    output.align = "left~"

    output.text = M.output_template__string:gsub('!([%w_]+)', function(name)
      local fn = M.renderers[name]
      if fn then
        return fn(s)
      end
    end)

  else

    local function pp(v)
      if type(v) == "table" and not is_simple_table(v) then
        return T'Complex table (expand to see)'
      else
        return devel.pp(v)
      end
    end

    output.align = "left~"
    output.text = render_values(values, pp)

  end
end

local function display_error(output, errmsg)
  output.style = style.error
  output.align = "center~"
  output.text = errmsg
end

function M.run()

  local env = create_env(M.funcs)
  local use_digits_separator = true

  local input = ui.Input{history="calc", expandx=true}

  local output_height = select(2, M.output_template__number:gsub("\n", "\n")) + 1
  local output = ui.ExtLabel{rows=output_height, expandx=true}

  input.on_change = function(self, do_expand)
    local values, errmsg = eval(self.text, env)
    if errmsg then
      display_error(output, errmsg)
    else
      if do_expand then
        devel.view(render_values(values, devel.pp), tostring)
      else
        display_result(output, values, use_digits_separator)
      end
    end
  end

  local chk_separator = ui.Checkbox{T"Use digits &separator", checked = use_digits_separator }
  chk_separator.on_change = function(self)
    use_digits_separator = self.checked
    input:on_change()
  end

  local btn_expand = ui.Button(T"E&xpand result")
  btn_expand.on_click = function()
    input:on_change(true)
  end

  local function show_help()
    local help = assert(require "utils.path".module_path("samples.apps.calc", "README.md"))
    mc.view(help)
  end

  init_styles()

  local dlg = ui.Dialog(T"Calculator")

  dlg:add(
    ui.Groupbox(T"Expression"):add(input),
    ui.Groupbox(T"Result"):add(output),
    ui.HBox{expandx=true}:add(
      chk_separator,
      ui.Space{expandx=true},
      btn_expand
    ),
    ui.Buttons():add(
      ui.Button{T"H&elp",on_click=show_help},
      ui.OkButton()
    )
  )

  local function bound(min, x, max)
    return math.max(min, math.min(x, max))
  end

  dlg:set_dimensions(nil, nil, bound(dlg:preferred_cols(), 80, tty.get_cols() - 30))

  dlg:run()

end

return M
