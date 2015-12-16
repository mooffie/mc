--- Editbox.
--
-- @classmod ui.Editbox

local ui = require("c.ui")

------------------------------------------------------------------------------
-- Reading
-- @section

--- Lines iterator.
--
-- Iterates over the lines. Returns the line and its number.
--
--    -- Highlight all the lines containing "Linux".
--    ui.Editbox.bind('C-y', function(edt)
--      for line, i in edt:lines() do
--        if line:find('Linux') then
--          edt:bookmark_set(i, tty.style('editor.bookmarkfound'))
--        end
--      end
--    end)
--
-- @function lines
function ui.Editbox.meta:lines()
  local max = self:get_max_line()
  local i = 0
  return function()
    i = i + 1
    if i > max then
      return nil
    else
      return self:get_line(i), i
    end
  end
end


--[[

MC's Edit widget doesn't quite have a function to get the "current"
word, so we implement it ourselves (which gives us flexibility, e.g., in
picking the "break" characters.)

For the record, editbuffer.c:edit_buffer_get_word_from_pos() fails at
the end of a word. editcmd.c:edit_find_word_start() fails at the start a
the word.

]]

---
-- The word on which the cursor stands.
--
-- This is simply a convenience wrapper around @{utils.text.extract_word}
-- (see there for explanation), implemented thus:
--
--    function ui.Editbox.meta:get_current_word()
--      return utils.text.extract_word(
--        self.line, self.cursor_xoffs
--      )
--    end
--
-- You may invoke it as a property:
--
--    ui.Editbox.bind('C-y', function(edt)
--      alert(edt.current_word)
--    end)
--
-- Or you may use the full method syntax (":get_current_word()") to also get
-- the portion of the word preceding the cursor:
--
--    ui.Editbox.bind('C-y', function(edt)
--      devel.view{edt:get_current_word()}
--    end)
--
-- See usage examples at @{delete}.
--
-- As a more elaborate example, here's a very simple implementation of
-- "word completion" for the editor:
--
--    --[[
--
--    Word-completion for the editor.
--
--    Stand on a word and hit C-y. You'll be shown a list of
--    all the words in the buffer sharing that prefix.
--
--    ]]
--
--    ui.Editbox.bind('C-y', function(edt)
--      local whole, part = edt:get_current_word()
--
--      if not whole      -- cursor is not on a word.
--          or part == "" -- cursor is on start of a word.
--      then
--        abort(T"Please stand on a word (past its first letter).")
--      end
--
--      local words = utils.table.new {}
--      for word in edt:sub(1):p_gmatch('\\b' .. part .. '[\\w_]+') do
--        words[word] = true
--      end
--
--      words = words:keys():sort()
--
--      if #words ~= 0 then
--
--        local lbox = ui.Listbox{items=words}
--
--        if ui.Dialog{compact=true}:add(lbox):popup(lbox) then
--          local word = lbox.value
--          edt:insert(word:sub(part:len()+1)) -- We need just the tail of the word.
--        end
--
--      else
--        tty.beep()   -- no completions found.
--      end
--
--    end)
--
-- Tip: To keep this "Word Completion" snippet short, no proper i18n handling
-- is done here. See @{git:complete_word.lua} for a version with proper
-- i18n handling.
--
-- @attr current_word
-- @property r
function ui.Editbox.meta:get_current_word()
  return require("utils.text").extract_word(
    self.line, self.cursor_xoffs
  )
end

------------------------------------------------------------------------------
-- Static functions
-- @section

---
-- Editor options.
--
-- A table containing some editbox options, which you can get and set.
--
--    -- Show line numbers when editing C files.
--    ui.Editbox.bind("<<load>>", function(edt)
--      if edt.syntax == "C Program" then
--        ui.Editbox.options.show_numbers = true
--      else
--        ui.Editbox.options.show_numbers = false
--      end
--    end)
--
-- Note that these are global options. Unfortunately, MC doesn't store
-- these values on each Editbox but in shared global variables. This means
-- that you can't have two Editboxes opened at once each having a different
-- `tab_size` value.
--
-- Available fields (options):
--
-- - tab_size  - The tab character width
-- - fake_half_tab - (boolean) Simulate tabs at half the size.
-- - expand_tab - (boolean) Emit spaces, instead of a tab, when the TAB key is pressed.
-- - show_numbers - (boolean) Show line numbers.
-- - wrap_column - The column for word-wrapping.
-- - show_right_margin - (boolean) Show where wrap_column is (works even if
--   wrapping is off). [A useful feature found in many other
--   editors.](http://www.emacswiki.org/FillColumnIndicator)
-- - save_position - (boolean) Save the file position when the editbox is closed.
--
ui.Editbox.options = setmetatable({}, {
  __index = function(t, option)
    return ui.Editbox.get_option(option)
  end,
  __newindex = function(t, option, val)
    return ui.Editbox.set_option(option, val)
  end
})

------------------------------------------------------------------------------
-- Static functions (syntax)
-- @section

---
-- Searches within the syntax list.
--
-- As mentioned @{syntax|earlier}, the @{syntax} property is a
-- human-readable pretty string instead of being a keyword. This utility
-- function tries its best to find a syntax string that matches a keyword.
--
--    assert(ui.Editbox.search_syntax("bison") == "Yacc/Bison Parser")
--    assert(ui.Editbox.search_syntax("PERL") == "Perl Program")
--    assert(ui.Editbox.search_syntax("C#") == "C# Program")
--
-- It returns **nil** if it finds none.
--
-- @function ui.Editbox.search_syntax
-- @args (keyword)
function ui.Editbox.search_syntax(needle)

  local all = ui.Editbox.get_syntax_list()

  -- The following sort() makes "C" match "C Program", not "C# Program".
  --
  -- Unfortunately, "C" will match the "C/C++ Program" that comes before
  -- "C Program" (such is the order because the locale is active).
  --
  -- Unfortunately also, "Java" would match "Java File" first, not
  -- "Java Program".
  --
  table.sort(all)

  needle = needle:lower():gsub('[^a-zA-Z0-9]', '%%%0')
  for _, syntax in ipairs(all) do
    if (" " .. syntax:lower() .. " "):find('%A'..needle..'%A') then
      return syntax
    end
  end

end

---
-- @section end

------------------------------------------------------------------------------

ui._setup_widget_class("Editbox")
