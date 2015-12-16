--[[

Makes the TAB key alone complete the word. No reason not to!

Idea taken from:

    https://www.midnight-commander.org/ticket/2875
    "I would like to propose a patch to mc to make autocompletion in mcedit
      by pressing only TAB key if we are not in indent."

]]

ui.Editbox.bind('tab', function(edt)
  local _, word_part_before_cursor = edt:get_current_word()

  -- 'word_part_before_cursor' is nil or "" unless we stand past a word character.
  -- (see its documentation!)
  if (word_part_before_cursor or "") == "" then
    return false  -- Continue with the default action.
  else
    edt:command "complete"
  end
end)
