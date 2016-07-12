--
-- Fun commands.
--

local colon = require('samples.colon')

colon.register_command {
  name = 'game',
  fn = function()
    require('samples.games.blocks').run()
  end,
  desc = T[[
Play a game of blocks.]],
}

colon.register_command {
  name = 'time',
  alias = 'clock',
  synopsis =
    "time\n" ..
    "clock",
  fn = function()
    require('samples.screensavers.clocks.analog').run()
  end,
  desc = T[[
Displays an analog clock.]],
}
