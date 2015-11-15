--[[

A clock with some debugging info.

]]

local clock = require('samples.accessories.clock')

clock.get_text = function()
  return
    (' %s | %dk | %s '):format(
      jit and jit.version or _VERSION,
      math.floor(collectgarbage 'count'),  -- floor() is for Lua 5.3+
      os.date '%H:%M:%S'
    )
end

clock.install()
