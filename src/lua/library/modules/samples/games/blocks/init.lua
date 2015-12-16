--
-- See copyright non-issues at https://bugzilla.redhat.com/show_bug.cgi?id=224627
--
-- Despite the resemblance to a well known game, there are no copyright issues
-- in bundling this game with the strictest Linux distros.
--

--[[

To install, add the following to your startup scripts:

  keymap.bind('C-x g b', function()
    require('samples.games.blocks').run()
  end)

]]

local run_dialog = require('samples.games.blocks.dialog').run_dialog

local is_running = false

local function run()
  if is_running then
    abort(T"The game is already running.")
  else
    is_running = true
    run_dialog()
    is_running = false
  end
end

return {
  run = run,
  setup = require('samples.games.blocks.board').setup,
}
