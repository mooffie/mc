--[[

Makes a screenshot.

This is just a little script to aid me in creating screenshots. You'll *certainly*
have to tweak it to adapt it to your system.

]]

local params = {
  crop = { 53, 17+1, 4+1, 4 },  -- the dimensions of my gterm's menu/decorations.
  dest = '/home/mooffie/mc/src/lua/doc/ss.png',
  temp = '/tmp/ss.xwd',
}

--
-- See http://www.imagemagick.org/Usage/crop/#chop
--
local function crop(input, output, top, right, bottom, left)
  os.execute(
    ([[ convert %q -chop 0x%d - |
        convert -gravity East -chop %dx0 - - |
        convert -gravity South -chop 0x%d - - |
        convert -chop %dx0 - %q ]]):format(
      input,
      top,
      right,
      bottom,
      left,
      output
    )
  )
end

keymap.bind('M-q', function()
  os.execute(("xwd -id %d > %q"):format(
    assert(os.getenv("WINDOWID"), "No WINDOWID env variable found."),
    params.temp
  ))
  crop(params.temp, params.dest, table.unpack(params.crop))
  fs.unlink(params.temp)
end)
