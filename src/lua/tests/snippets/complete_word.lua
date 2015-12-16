-- This is an i18n-aware version of the code example given in the documentation for Editbox.current_word.

--[[

Word-completion for the editor.

Stand on a word and hit C-y. You'll be shown a list of
all the words in the buffer sharing that prefix.

]]

ui.Editbox.bind('C-y', function(edt)
  local whole, part = edt:get_current_word()

  if not whole     -- cursor is not on a word.
     or part == "" -- cursor is on start of a word.
  then
    abort(T"Please stand on a word (past its first letter).")
  end

  local words = utils.table.new {}
  -- i18n: we support non-ASCII identifiers by using the 'u' flag.
  for word in edt:sub(1):p_gmatch {'\\b' .. part .. '[\\w_]+', edt:is_utf8() and 'u' or ''} do
    if word ~= whole then
      words[word] = true
    end
  end

  words = words:keys():sort()

  -- i18n: to show the words in the UI we must first convert them to the terminal's encoding.
  local items = words:imap(function(word)
    return {
      edt:to_tty(word),
      value=word
    }
  end)

  if #words ~= 0 then

    local lbox = ui.Listbox{items=items}

    if ui.Dialog{compact=true}:add(lbox):popup(lbox) then
      local word = lbox.value
      edt:insert(word:sub(part:len()+1)) -- We need just the tail of the word.
    end

  else
    tty.beep()    -- no completions found.
  end

end)
