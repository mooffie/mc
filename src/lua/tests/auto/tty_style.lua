
local ensure = devel.ensure

ui.open()

local function test()

  -- Note: The following works only for skins that have "editor.bookmark" defined
  -- and where its fg/bg aren't empty (which makes them inherit from "editor._default_").
  ensure.equal(
    tty.style("editor.bookmark"),
    tty.style(tty.skin_get("editor.bookmark", "*SKIN MISSING PROPERTY*")),
    'tty.style() and tty.skin_get()'
  )

  local red_white_underline_style = tty.style("red, white; underline")
  local red_white_underline_struct = tty.destruct_style(red_white_underline_style)

  ensure.equal(red_white_underline_struct.fg, "red", 'tty.destruct_style(), 1')
  ensure.equal(red_white_underline_struct.bg, "white", 'tty.destruct_style(), 2')
  ensure(red_white_underline_struct.attr.underline, 'tty.destruct_style(), 3')

end

test()
