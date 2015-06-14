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
-- Syntax
-- @section

---
-- Syntax-highlights a string.
--
-- This adds a string (typically a keyword) to the syntax definition. This
-- makes the string shown in a different style than normal text.
--
-- Example:
--
--    -- When you're editing source code you sometimes wish to see
--    -- all the places on the screen where a variable is used.
--    --
--    -- In Vim this is done with the * (asterisk) key. Here we use
--    -- alt-* instead.
--    --
--    ui.Editbox.bind('M-*', function(edt)
--      abortive(edt.current_word, T'Stand on a word, will you?')
--      edt:add_keyword(edt.current_word, tty.style('white, red'), nil, 'all')
--      edt:redraw()
--    end)
--
-- Another example:
--
--    -- Spellcheck the file.
--    -- Misspelled words will be highlighted.
--    ui.Editbox.bind('C-c', function(edt)
--      local f = io.popen('spell < ' .. edt.filename .. ' | sort | uniq')
--      for word in f:lines() do
--        edt:add_keyword(word, tty.style('white, red'), nil, 'spellcheck')
--      end
--      edt:redraw()
--      f:close()
--    end)
--
-- (For better spellchecking, see @{git:editbox/speller.lua}.)
--
-- Another example:
--
--    --[[
--
--    When you read novels you sometimes want people's names
--    highlighted.
--
--    Look no further :-)
--
--    With this script you can add "Actors:" lines to the first
--    lines of your novel's text to make that happen. Example:
--
--       Actors: Benedict Brand Corwin Eric Julian Oberon (male)
--       Actors: Deirdre Fiona Flora Llewella (female)
--
--    It's probably convenient to use this on 256 color terminals
--    only, where we can pick non-intrusive colors.
--
--    ]]
--
--    ui.Editbox.bind('<<load>>', function(edt)
--
--      local styles = {
--        -- By specifying only the foreground color we get the default
--        -- background color, which is usually (not always) the editor's
--        -- background as well. You may, of course, explicitly specify
--        -- the background here.
--        male   = tty.style {color='yellow', hicolor='color159'}, -- Bluish
--        female = tty.style {color='brown',  hicolor='color219'}, -- Pinkish
--        object = tty.style {color='white',  hicolor='color186'}, -- Yellowish
--        place  = tty.style {color='green',  hicolor='color120'}, -- Greenish
--      }
--
--      for line, i in edt:lines() do
--        -- The following "[o]" is a trick to prevent that line from
--        -- being recognized as an Actors line.
--        local names, gender = line:match "Act[o]rs:(.*)%((.*)%)"
--        if names then
--          for name in names:gmatch "[^%s,]+" do
--            edt:add_keyword(name, abortive(styles[gender], 'missing style ' .. gender), nil, 'all')
--          end
--        end
--        if i > 50 then  -- look in 50 first lines only.
--          break
--        end
--      end
--
--    end)
--
-- [info]
--
-- You must redraw the editbox, by calling @{ui.redraw|:redraw()}, to see the
-- effect on the text. For performance reasons this is _not_ done automatically after
-- each :add_keyword().
--
-- Of course, if you're doing your stuff in `<<load>>`, as in one example above, you
-- don't need to call @{ui.redraw|:redraw()} because the text is drawn afterwards in
-- any case.
--
-- [/info]
--
-- [note]
--
-- There's currently no remove_keyword() method to cancel the effect
-- of add_keyword().
--
-- To remove any keywords you added you can reset the syntax definition
-- by doing:
--
--    edt.style = edt.style
--
-- Or, as a user, press `C-s` twice (the first time disables
-- syntax highlighting; the second enables it again).
--
-- [/note]
--
-- @function add_keyword
-- @param s The string to highlight.
-- @param style The style to highlight it in.
-- @param[opt] non_whole Whether the string must be "whole" (bounded by non-word characters) or not.
-- @param[opt] contexts_type One of 'default', 'all', 'spellcheck',
--  '!spellcheck'. Syntaxes are composed of @{git:c.syntax|"contexts"}.
--  E.g., in a programming language the 'default' context holds normal code,
--  another context is for comments, another for strings, etc. By default
--  the keyword will be added to the 'default' context only (which means
--  that it _won't_ be recognized in comments and strings). Contexts are also
--  marked as being appropriate, or not, for spell checking.

local WHOLE_WORD_DEFAULT = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_01234567890"

function ui.Editbox.meta:add_keyword(s, style, non_whole, range)
  assert(type(s) == 'string', E"I'm expecting a string as the first argument.")
  assert(type(style) == 'number', E"I'm expecting a style as the second argument.")

  local whole = not non_whole
  local left = (whole and s:find '^[a-zA-Z_0-9]') and WHOLE_WORD_DEFAULT or nil
  local right = (whole and s:find '[a-zA-Z_0-9]$') and WHOLE_WORD_DEFAULT or nil
  self:_add_keyword(s, left, right, range or 'default', style)
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
-- - fake_half_tab - Simulate tabs at half the size.
-- - expand_tab - Emit spaces, instead of a tab, when the TAB key is pressed.
-- - show_numbers - Show line numbers.
-- - wrap_column - The column for word-wrapping.
-- - show_right_margin - Show where wrap_column is, but works even if
--   wrapping is off. [A useful feature found in many other
--   editors.](http://www.emacswiki.org/FillColumnIndicator)
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
--    ui.Editbox.search_syntax("bison") == "Yacc/Bison Parser"
--    ui.Editbox.search_syntax("PERL") == "Perl Program"
--    ui.Editbox.search_syntax("C#") == "C# Program"
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
