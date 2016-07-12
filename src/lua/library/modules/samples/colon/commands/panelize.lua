--[[

Panelization-related commands.

These commands were written as a demonstration of solving:

  https://mail.gnome.org/archives/mc/2016-May/msg00012.html
  http://midnight-commander-user-discussion.2516130.n2.nabble.com/save-search-results-export-to-file-td7575173.html

]]

--[[

@todo:

* Perhaps instead of :pload we should have :pexec to run an arbitrary
  shell command? This would be more useful. OTOH: (1) it won't support
  the VFS; (2) there's already 'C-x !'.

* Perhaps this :pexec could have an extra feature: it'd take everything
  till the ":". Useful for grep output. It could detect this either by
  checking that the file (the part before the ":") exists, or by assuming
  that if all lines have ":" then it's a grep output.

]]

local colon = require('samples.colon')

local List = utils.table.List

--
-- Save listing to file.
--
local function cmd_dump(pnl, trg)
  abortive(trg, T"You need to name the file to save to.")
  if fs.file_exists(trg) then
    if not prompts.confirm(T"File '%s' exists. Overwrite it?":format(trg)) then
      return
    end
  end
  assert(fs.write(trg,
    List(pnl:files()):sub(2):concat "\n",  -- sub() gets rid of ".."
    "\n"
  ))
  pnl:reload()  -- So the user sees this new file (unless panel is panelized or filtered).
end

--
-- Load listing from file.
--
local function cmd_load(pnl, src)
  abortive(src, T"You need to name the file to load from.")
  abortive(fs.file_exists(src))
  pnl:panelize_by_list( List(fs.lines(src)) )
end

colon.register_command {
  name = 'pdump',
  fn = cmd_dump,
  context_type = 'Panel',
  synopsis = 'pdump <destination-file>',
  desc = T[[
Writes the names of the files displayed in a panel to a text file.
Note: If the panel is 'panelized', you won't, of course, see the new file
in the list afterwards. Make the panel reload the directory to see it.]],
}

colon.register_command {
  name = 'pload',
  fn = cmd_load,
  context_type = 'Panel',
  synopsis = 'pload <source-file>',
  desc = T[[
Makes a panel display the files listed in a text file (aka 'panelize').
Note: files that don't exist won't be shown.]],
}
