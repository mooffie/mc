--[[

WordStar key-bindings (also Turbo Pascal's).

Installation:

    require('samples.editbox.wordstar')

It doesn't behave exactly as WordStar, but it's the best we can do
without enhancing the editor's C code.

Idea taken from:

    https://www.midnight-commander.org/ticket/2644

Tip: You can invoke the original C-k and C-q by pressing them twice.

]]

---------------------------- Block commands (C-k) ----------------------------

ui.Editbox.bind("C-k b", function(edt)  -- "Block Beginning"
  edt:command "unmark"
  edt:command "mark"
end)

ui.Editbox.bind("C-k k", function(edt)  -- "Block End"
  if edt:get_markers() then
    edt:command "mark"
  end
end)

ui.Editbox.bind("C-k h", function(edt)  -- "Block Hide"
  edt:command "unmark"
end)

ui.Editbox.bind("C-k c", function(edt)  -- "Block Copy to Cursor Position"
  edt:command "copy"
end)

ui.Editbox.bind("C-k v", function(edt)  -- "Block Move to Cursor Position"
  edt:command "move"
end)

ui.Editbox.bind("C-k y", function(edt)  -- "Block Delete"
  if edt:get_markers() then  -- otherwise it deletes the current line.
    edt:command "remove"
  end
end)

ui.Editbox.bind("C-k w", function(edt)  -- "Write Block to File"
  edt:command "BlockSave"
end)

ui.Editbox.bind("C-k r", function(edt)  -- "Insert File"
  edt:command "InsertFile"
end)

ui.Editbox.bind("C-k ]", function(edt)  -- "Edit Copy to Clipboard"
  edt:command "store"
end)

ui.Editbox.bind("C-k [", function(edt)  -- "Paste from Clipboard"
  edt:command "paste"
end)

ui.Editbox.bind("C-k C-k", function(edt)  -- invoke the original C-k.
  edt:command "DeleteToEnd"
end)

--
-- The following might have originated in FreePascal:
--   ( http://www.freepascal.org/docs-html/user/userse32.html )
--

ui.Editbox.bind("C-k i", function(edt)
  edt:command "BlockShiftRight"
end)

ui.Editbox.bind("C-k u", function(edt)
  edt:command "BlockShiftLeft"
end)

-------------------------------- Jumps (C-q) ---------------------------------

ui.Editbox.bind("C-q b", function(edt)  -- "Go To Block Beginning"
  local beginning = edt:get_markers()
  if beginning then
    edt.cursor_offs = beginning
  end
end)

ui.Editbox.bind("C-q k", function(edt)  -- "Go To Block End"
  local _, ending = edt:get_markers()
  if ending then
    edt.cursor_offs = ending + 1
  end
end)

ui.Editbox.bind("C-q C-q", function(edt)  -- invoke the original C-q.
  edt:command "InsertLiteral"
end)
