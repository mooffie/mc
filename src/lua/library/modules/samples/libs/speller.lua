--[[

Spellchecker support.

]]

local M = {}

--
-- The first speller program found will be used.
--
-- End-users can tweak this by require()ing this module
-- and altering this table.
--
M.spellers = {
  {
    test="aspell usage",
    commands={
      scan="aspell list",
      suggest="echo ^%q | aspell -a",
      add="(echo '*'%q; echo '#') | aspell -a",
    }
  },
  {
    test="ispell -v",
    commands={
      scan="ispell -l",
      suggest="echo ^%q | ispell -a",
      add="(echo '*'%q; echo '#') | ispell -a",
    }
  },
  -- We put hunspell last because of this problem:
  --   http://superuser.com/questions/588548/make-hunspell-ignore-leading-and-trailing-single-quote-characters-apostrophes
  {
    test="hunspell -v",
    commands={
      scan="hunspell -l",
      suggest="echo ^%q | hunspell -a",
      add="(echo '*'%q; echo '#') | hunspell -a",
    }
  },
  {
    test="spell",
    commands={
      scan="spell",
    }
  },
}

local append = table.insert
local select_program__with_message = import_from('samples.libs.os', { 'select_program__with_message' })

---
-- Spell-check a file
--
-- Return a list of misspelled words. The list may be empty if no misspellings
-- found.
--
-- Raises an 'abort' if it can't find the speller program.
--
function M.check_file(path)

  local prog = abortive(select_program__with_message(M.spellers, T"I can't do spell checking."))

  local words = {}

  -- We have to use fs.getlocalcopy() as the file may reside in a zip archive, for example.
  local local_path = fs.getlocalcopy(path)

  local CMD = prog.commands.scan .. " < %q | sort | uniq"
  local f = io.popen(CMD:format(local_path))
  for word in f:lines() do
    append(words, word)
  end
  f:close()

  fs.ungetlocalcopy("<unneeded>", local_path, false)

  return words

end

---
-- Spell-check a single word.
--
-- Returns a list of spelling suggestions. If it can figure nothing to suggest,
-- or if the word is spelled ok, return false.
--
-- Raises an 'abort' if it can't find the speller program.
--
function M.get_suggestions(word)

  local prog = abortive(select_program__with_message(M.spellers, T"I can't do spell checking."))

  local CMD = abortive(prog.commands.suggest, T"Your speller program doesn't know how to provide suggestions to misspelled words")
  local f = io.popen(CMD:format(word))
  for line in f:lines() do
    local _, suggestions = line:match "^& (%S+) [^:]+: (.*)"
    if suggestions then
      return suggestions:l_tsplit(", ")
    end
  end
  f:close()

  return false

end

---
-- Add a word to the user's dictionary.
--
function M.add_word(word)

  local prog = abortive(select_program__with_message(M.spellers, T"I can't do spell checking."))

  local CMD = abortive(prog.commands.add, T"Your speller program don't know how to save words in a user dictionary.")
  os.execute(CMD:format(word) .. " > /dev/null")

end

return M
