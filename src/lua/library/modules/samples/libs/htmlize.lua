--[[

Turns the screen, or a syntax-highlighted Editbox, into HTML.

Usage example:

    local htmlize = require('samples.libs.htmlize')

    htmlize.palette = htmlize.palettes.mooffie   -- Optional. Use a nice dark background instead of bluish one.

    keymap.bind('C-y', function()
      htmlize.htmlize_to_file(tty.get_canvas(), '/tmp/out.html')
    end)

    ui.Editbox.bind('C-y', function(edt)
      htmlize.htmlize_to_file(edt, '/tmp/out.html')
    end)

    -- You may also htmlize source files directly, without loading them into the editor:
    htmlize.htmlize_to_file('/path/to/file.c', '/tmp/out.html')


(Do `devel.view(htmlize.palettes)`, or just read this source file, to
see the available 16-colors palettes.)

Also see the mcscript executable src/lua/misc/bin/htmlize if you wish to
highlight source files from the command line.

@module htmlize

]]

local append = table.insert
local memoize = require('utils.magic').memoize

local M = {}

M.template = [[
<style type="text/css">
.syn_background {
  padding: 0.5em 0.5em;
}
%s
</style>
<pre class="syn_background">%s</pre>
]]


local COLOR_BLACK = 0
local COLOR_WHITE = 7
local COLOR_DEFAULT = -1   -- Default color of the terminal.

M.bold_range = { min = 8, max = 15 } -- Make colors 8..15 bold, 0..7 normal. You may change that.

----------------------------------- 16 colors palettes -----------------------------------

--[[
The following color palettes were copied from GNOME Terminal using:

   $ gconftool --get /apps/gnome-terminal/profiles/Default/palette

(Note: the command no longer works for me. google: "Terminal now uses GSettings and DConf instead of GConf.")
]]

M.palettes = {
  tango = '#000000000000:#CCCC00000000:#4E4E9A9A0606:#C4C4A0A00000:#34346565A4A4:#757550507B7B:#060698209A9A:#D3D3D7D7CFCF:#555557575353:#EFEF29292929:#8A8AE2E23434:#FCFCE9E94F4F:#72729F9FCFCF:#ADAD7F7FA8A8:#3434E2E2E2E2:#EEEEEEEEECEC',
  linux = '#000000000000:#AAAA00000000:#0000AAAA0000:#AAAA55550000:#00000000AAAA:#AAAA0000AAAA:#0000AAAAAAAA:#AAAAAAAAAAAA:#555555555555:#FFFF55555555:#5555FFFF5555:#FFFFFFFF5555:#55555555FFFF:#FFFF5555FFFF:#5555FFFFFFFF:#FFFFFFFFFFFF',
  xterm = '#000000000000:#CDCB00000000:#0000CDCB0000:#CDCBCDCB0000:#1E1A908FFFFF:#CDCB0000CDCB:#0000CDCBCDCB:#E5E2E5E2E5E2:#4CCC4CCC4CCC:#FFFF00000000:#0000FFFF0000:#FFFFFFFF0000:#46458281B4AE:#FFFF0000FFFF:#0000FFFFFFFF:#FFFFFFFFFFFF',
  rxvt  = '#000000000000:#CDCD00000000:#0000CDCD0000:#CDCDCDCD0000:#00000000CDCD:#CDCD0000CDCD:#0000CDCDCDCD:#FAFAEBEBD7D7:#404040404040:#FFFF00000000:#0000FFFF0000:#FFFFFFFF0000:#00000000FFFF:#FFFF0000FFFF:#0000FFFFFFFF:#FFFFFFFFFFFF',

  --
  -- User-contributed palettes:
  --

  -- My own. It uses a dark grey background.
  mooffie = '#000000000000:#CCCC00000000:#0000AAAA0000:#E4E4AAAA6F6F:#434343434949:#DEB70000DEB7:#0000AAAAAAAA:#AAAAAAAAAAAA:#555555555555:#FFFF55555555:#5555FFFF5555:#FFFFFFFF5555:#55555555FFFF:#FFFF5555FFFF:#5555FFFFFFFF:#FFFFFFFFFFFF',
}

M.palette = M.palettes.rxvt  -- 'rxvt' seems to be the least awful of the bluish palettes. You can override this after require().

-- The parsed palette.
local palette_tbl = nil

-- Parses the palette string.
local function parse_palette()

  palette_tbl = {}

  for r,g,b in M.palette:gmatch [[#(..)..(..)..(..)..]] do
    append(palette_tbl, "#" .. r .. g .. b)
  end

  assert(#palette_tbl == 16, "Malformed palette string")

  --devel.view(palette_tbl)
end

------------------------ Terminal-color to HTML-color conversion -------------------------

--
-- Two charts explaining the 256 colors scheme of the terminal:
--
--   http://www.calmar.ws/vim/256-xterm-24bit-rgb-color-chart.html
--   http://en.wikipedia.org/wiki/File:Xterm_256color_chart.svg
--
-- The first is easier to grok (but errs in colors #241 and #242).
--

-- The values of a single dimension in the RGB 6x6x6 cube.
local rgb_val = { [0] = "00", "5F", "87", "AF", "D7", "FF" }

--
-- Converts a terminal color (a number from 0 to 255, or -1) to
-- an HTML hex color (e.g., "#FF0000").
--
local function html_color(idx)

  if idx == COLOR_DEFAULT then

    return "inherit"  -- That's a CSS value.

  elseif idx > 255 or idx < 0 then

    error(E"I don't recognize the color '%d'. Please file a bug report.":format(idx))

    return "ERR"

  elseif idx >= 232 then

    -- Grayscales.
    local n = idx - 232
    local third = ("%02X"):format(n*10 + 8)
    return "#" .. third .. third .. third

  elseif idx >= 16 then

    -- The RGB 6x6x6 cube.
    local n = idx - 16
    local r, g, b = math.floor(n/36) % 6,
                    math.floor(n/6) % 6,
                    n % 6
    return "#" .. rgb_val[r] .. rgb_val[g] .. rgb_val[b]

  elseif idx >= 0 then

    -- The 16 colors palette.

    if not palette_tbl then
      parse_palette()
    end

    return palette_tbl[idx + 1]

  end
end

---------------------------- Terminal-style to CSS conversion ----------------------------

-- A few special styles used for monochrome (do 'mc -b').
local special_styles = {
  A_REVERSE = { ifg=COLOR_BLACK, ibg=COLOR_WHITE, attr={} },
  A_BOLD = { ifg=COLOR_WHITE, ibg=COLOR_BLACK, attr={bold=true} },
  A_BOLD_REVERSE = { ifg=COLOR_BLACK, ibg=COLOR_WHITE, attr={bold=true} },
  A_UNDERLINE = { ifg=COLOR_WHITE, ibg=COLOR_BLACK, attr={underline=true} },
}

local function canonize(style)
  return special_styles[style.fg] or style
end

--
-- Converts a "curses" style to CSS declarations.
--
local function style_to_css(style, page_style, skip_attrs)
  local s = ""

  style = canonize(style)
  page_style = canonize(page_style)

  local ifg = style.ifg
  local ibg = style.ibg

  if style.attr.reverse then
    ibg, ifg = ifg, ibg
  end

  if ifg ~= page_style.ifg then
    s = "color: " .. html_color(ifg)
  end
  if ibg ~= page_style.ibg then
    s = s .. "; background-color: " .. html_color(ibg)
  end

  if not skip_attrs then
    local bold = (ifg >= M.bold_range.min and ifg <= M.bold_range.max)
    if style.attr.bold or bold then
      s = s .. "; font-weight: bold"
    end
    if style.attr.underline then
      s = s .. "; text-decoration: underline"
    end
    if style.attr.italic then
      s = s .. "; font-style: italic"
    end
  end

  return s
end

local function style_idx_to_css(style_idx, page_style, skip_attrs)
  return style_to_css(tty.destruct_style(style_idx), page_style, skip_attrs)
end

------------------------------------------------------------------------------------------

--
-- Breaks the whole text into segments each belonging to a single style.
--
local function segmentize(edt)

  local segs = {}
  local handle_byte

  do
    -- de-facto private variables.
    local last_style
    local seg

    -- Note that all our memoized functions are local variables inside functions.
    -- We mustn't make them global because we don't want their cache to live
    -- long: MC re-uses styles.
    local destruct_style = memoize(tty.destruct_style)

    function handle_byte(pos, style)
      if style ~= last_style then
        if seg then
          -- Finish the current segment.
          seg.stop = pos - 1
          seg.text = edt:sub(seg.start, seg.stop)
          append(segs, seg)
        end

        -- Start a new segment
        seg = {}
        seg.start = pos
        seg.style = destruct_style(style)
      end
      last_style = style
    end
  end

  for b = 1, edt:len() do
    handle_byte(b, edt:get_style_at(b))
  end
  handle_byte(edt:len() + 1, -1)  -- finish the last segment.

  return segs

end

--[[

We want the user to be able to relatively easily edit the HTML to change
its appearance. So we use CSS classes, to centralize the styles in one
place, instead of embedding the styles on the HTML elements.

We don't know anything about the semantics of our styles, so we can't
have class names like "syn_keyword", "syn_number", etc. Our class names
instead derive from the text of the CSS itself. That's the best we can
do.

]]
local function gen_css_class_name(s)
  return
    s
      :gsub('background%-color', 'background'):gsub('font%-weight', '')  -- Makes the names shorter.
      :gsub('[^%w]+', '_')  -- Does the actual work.
end

local function html_escape(s)
  -- The parentheses are important: gsub() returns more than one value.
  return (s:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'))
end

---
-- Htmlizes an Editbox or a Canvas.
--
-- The object htmlized has to support the following methods:
--
--  * get_style_at
--  * len
--  * sub
--
-- Returns two strings: the CSS, and the HTML.
--
function M.htmlize(edt)

  if not edt.get_style_at then
    require('samples.libs.htmlize-canvas')
  end

  assert(edt.get_style_at, "I can only HTMLize certain objects, like ui.Editbox and ui.Canvas.")

  local segs = segmentize(edt)
  --devel.view(segs)

  local style_to_css = memoize(style_to_css)
  local gen_css_class_name = memoize(gen_css_class_name)

  local html = {}      -- accumulates the HTML.
  local css_defs = {}  -- accumulates the CSS definitions.

  local page_style = tty.destruct_style(edt:get_style_at(-1))

  css_defs['syn_background'] = style_to_css(page_style, {}, true)

  for _, seg in ipairs(segs) do

    local css = style_to_css(seg.style, page_style)
    local css_class_name = "syn_" .. gen_css_class_name(css)

    if css ~= "" then
      css_defs[css_class_name] = css
      append(html, '<span class="' .. css_class_name .. '">' .. html_escape(seg.text) .. '</span>')
    else
      append(html, html_escape(seg.text))
    end

  end

  local css_text = ""
  for css_class_name, css_fragment in pairs(css_defs) do
    css_text = css_text .. (".%s { %s }\n"):format(css_class_name, css_fragment)
  end

  return css_text, table.concat(html)
end

---
-- Htmlizes into a file.
--
-- The input may be an Editbox, a Canvas, or a string denoting a path
-- to some source file (which will be loaded into a non-visible Editbox
-- and htmlized).
--
function M.htmlize_to_file(input, output_filename)

  if type(input) == "string" then
    local input_filename = input
    assert(fs.open(input_filename, "r")):close()
    input = ui.Editbox()
    input:load(input_filename)
  end

  local css, source = M.htmlize(input)

  local f = assert(fs.open(output_filename, "w"))
  assert(f:write(M.template:format(css, source)))
  assert(f:close())

end

------------------------------------------------------------------------------------------

return M
