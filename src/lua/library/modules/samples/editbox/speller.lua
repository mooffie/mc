--[[

Speller support.

It highlights misspelled words and shows spelling suggestions.

Installation:

Add the following to your startup scripts:

    ui.Editbox.bind('M-$', function(edt)
      require('samples.editbox.speller').check_word(edt)
    end)
    ui.Editbox.bind('M-!', function(edt)
      require('samples.editbox.speller').check_file(edt)
    end)

NOTES:

- Syntax highlighting must be turned on for you to see misspelled words.

- Highlighting doesn't work on mono terminals. That's a limitation of
MC.

- To clear the display of misspelled words, press C-s twice (C-s is the
default binding for "Toggle syntax highlighting".)

- The speller used will be one of aspell/ispell/hunspell. See
documentation in 'modules/samples/libs/speller.lua' if you want to
change this.

]]

local M = {
  style = {
    -- MC doesn't support syntax highlighting on mono terminals. Nevertheless,
    -- we provide a style for it in case this changes in the future.
    misspelling = { color='white, red', mono='underline' },
  }
}

local speller = require('samples.libs.speller')

function M.check_word(edt)

  abortive(edt.current_word, T'Stand on a word, will ya?')

  local word, partial_word = edt:get_current_word()
  local suggestions = speller.get_suggestions(word)

  if suggestions then

    local dlg = ui.Dialog{
      T"%d suggestions":format(#suggestions),
      compact=true, padding=0
    }

    local lstbx = ui.Listbox{items=suggestions}

    dlg:add(lstbx)
    dlg:add(ui.ZLine())
    dlg:add(ui.Button{T"&Replace word", result="replace", type="default"})
    dlg:add(ui.Button{T"&Add word to dict", result="add"})

    if dlg:popup(lstbx) then
      if dlg.result == "add" then
        speller.add_word(word)
      else
        -- Replace word.
        edt.cursor_offs = edt.cursor_offs - partial_word:len()
        edt:delete(word:len())
        edt:insert(lstbx.value)
      end
    end

  else
    alert(T"This word seems fine")
  end

end

function M.check_file(edt)

  if edt.modified then
    abort(T'Save the file first.')
  end

  if not edt.filename then
    abort(T'Save the file first. It has to be a file on disk so the lint program can read it.')
  end

  local style = utils.table.map(M.style, tty.style)

  local function spellcheck()
    local words = speller.check_file(edt.filename)
    for _, w in ipairs(words) do
      edt:add_keyword(w, style.misspelling, {range='spellcheck'})
    end
    edt:redraw()
    return #words
  end

  local count = prompts.please_wait(T'Spell checking', spellcheck)
  if count == 0 then
    prompts.flash(T"All's fine")
  else
    -- Unfortunately, we can't show a T"%d misspellings found" flash because,
    -- when spellchecking a computer program, variable names too will be
    -- considered as such but only those in comments will be highlighted. So
    -- we'll have "230 misspelling found" but the user will see only 4
    -- highlighted...
  end

end

return M
