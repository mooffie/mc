--[[

Terminal-related facilities.

We just add a little to the C module here.

]]
--- @module tty

local tty = require("c.tty")

local append = table.insert

------------------------------------------------------------------------------
-- Styles
--
-- @section style

--
-- Converts " red ,, white shoes;  baldy " to {"red", "", "white shoes", "baldy"}.
--
local function split_on_commas(s)
  local parts = {}
  for w in (s .. ";"):gmatch("%s*([^;,]-)%s*[;,]") do
    append(parts, w)
  end
  return parts
end

--
-- Picks the right style out of { color=..., mono=... } 
--
local function choose_style(t)
  local function mono()
    return t.mono and (";;" .. t.mono)
  end

  local color

  if tty.is_hicolor() then
    color = t.hicolor or t.color or mono()
  elseif tty.is_color() then
    color = t.color or mono() or (
                -- If there isn't even "hicolor", most probably it's a spelling error in "color",
                -- so we don't blindly do 'or ""' as in the following "mono" case.
              t.hicolor and "")
  else -- mono
    color = mono() or ""
  end

  return color
end

--
-- Given a string, like "red, white", "editor.bookmark", creates a style.
--
local function create_style(s)
  if s:find "%." then
    local group, name = s:match '(.*)%.(.*)'
    return tty._skin_style(group, name)
  else
    local a, b, c = table.unpack(split_on_commas(s))

    local fg   = (a or "") == "" and "base" or a
    local bg   = (b or "") == "" and "base" or b
    local attr = (c or "") == "" and ""     or c

    -- MC doesn't validate attributes (unlike with color names), so in the meantime we do it ourselves:
    if attr ~= "" and not regex.find(attr .. "+", [[^(base\+|bold\+|underline\+|reverse\+|blink\+|italic\+)+$]]) then
      error(E"Invalid attribute '%s': valid value is one or more of 'bold', 'underline', 'reverse', 'blink', 'italic', separated by '+'.":format(attr), 2)
    end

    return tty._style(fg, bg, attr)
  end
end

--[[-

Creates a style.

The argument for this function is a description of a style. The function
"compiles" this description and returns an integer which can be used
wherever a style value is required.

There are three ways to describe a style.

__(1)__ As a string with the three components (foreground
color, background color, attributes -- in this order) separated by commas
or semicolons:

    local style = tty.style('white, red; underline')
    local style = tty.style('white; red, underline')
    local style = tty.style('white, red, underline')

Type `mc --help-color` at the shell to see the valid names.

Any of the components may be omitted:

    local style = tty.style('white, red')
    local style = tty.style(', red')
    local style = tty.style(',, underline')
    local style = tty.style('')

__(2)__ As a string naming a skin property:

    local style = tty.style('editor.bookmark')

__(3)__ You may also specify several style in a table, keyed by the
terminal type:

    local style = tty.style {
      mono = "reverse",
      color = "yellow, green",
      hicolor = "rgb452, rgb111"
    }
    -- 'hicolor' is for 256 color terminals.

For examples of using styles, see @{ui.Canvas} and @{ui.Editbox:bookmark_set}.

[note]

There is a limit to the number of styles that can be allocated. Generally,
you'll be able to allocate around two hundred. An exception will be raised
when you reach the limit.

If the same style description is used again and again, it will be allocated
only once.

[/note]

@function style
@args (spec)

]]
function tty.style(v)

  if not tty.is_ui_ready() then
    error(tty._generate_error_message("style"), 2)
  end

  local style

  if type(v) == "string" then
    style = v
  elseif type(v) == "table" then
    style = choose_style(v)
    if not style then
      error(E"No style specified for this screen.", 2)
    end
  else
    error(E"Invalid style format. I'm expecting a string or a table, but I got %s.":format(type(v)), 2)
  end

  return create_style(style)
end

------------------------------------------------------------------------------
-- Misc functions
--
-- @section misc

--- Fetches a skin's property.
--
-- Example:
--
--    tty.skin_get('invasion-from-mars.missile', '>===))>')
--
--    tty.skin_get('chess.white-knight', tty.is_utf8() and '♘' or 'N')
--
--    tty.skin_get('Lines.horiz', '-')
--
-- Skin files are, by convention, encoded in UTF-8, and the properties read
-- from them are converted to the terminal's encoding. Therefore you can
-- directly use them in the UI (in widgets' data and @{ui.Canvas|drawing}
-- functions): there's no need to re-encode them first.
--
-- @function skin_get
-- @param property_name A string of the form *group.name*.
-- @param default A value to return if the property wasn't found.
--
function tty.skin_get(locator, default)

  if not tty.is_ui_ready() then
    error(tty._generate_error_message("skin_get"), 2)
  end

  if type(locator) ~= "string" or not locator:find "%." then
    error(E"The first argument must be a string in the format group.name", 2)
  end

  if type(default) ~= "string" then
    error(E"You must provide a default string", 2)
    --
    -- We don't *have* to make the 'default' argument mandatory.
    --
    -- It amounts to the question of whether we want our users to write...
    --
    --    tty.skin_get('app.whatever') or 'some-default'
    --
    -- ...or whether we want to force them to write:
    --
    --    tty.skin_get('app.whatever', 'some-default')
    --
    -- The latter is better because users can't forget to provide a default
    -- and exceptions about doing something with 'nil' won't creep up down
    -- the road.
  end

  local group, name = locator:match '(.*)%.(.*)'
  return tty._skin_get(group, name, default)
end

---
-- @section end

------------------------------------------------------------------------------

return tty
