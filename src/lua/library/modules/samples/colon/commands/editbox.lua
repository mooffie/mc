--
-- Editbox-related commands.
--

local colon = require('samples.colon')

colon.register_command {
  name = 'spell',
  context_type = 'Editbox',
  fn = function(edt)
    require('samples.editbox.speller').check_file(edt)
  end,
  desc = T[[
Spell-checks the document.
(After executing this command you can press C-s twice to clear the
markings, if you wish.)]],
}
