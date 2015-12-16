--[[

Lints your program files.

That is, it checks for syntax errors right in the editor. This saves you
time because you catch errors early on instead of waiting for some lengthy
build process.

Installation:

    ui.Editbox.bind('f12', function()
      require('samples.editbox.linter').run()
    end)

You may also want to do the following, which fixes 'M-o' to flush
*all* bookmarks, including the ones Linter creates (by default it
flushes only those set with 'M-k').

    ui.Editbox.bind('M-o', function(edt)
      edt:bookmark_flush()
    end)

You may register your own lint programs:

    require('samples.editbox.linter').primary_checkers['FooBar Program'] = {
      prog = 'foobar -c "%s" 2>&1',
      pattern = ':(%d+):'
    }

--

You can define alternative registries. Linter already comes with
one alternative called 'secondary_checkers', used for disassemblers:

    ui.Editbox.bind('C-x f12', function()
      local mod = require('samples.editbox.linter')
      mod.run(mod.secondary_checkers)
    end)

]]

local append = table.insert

local M = {
  style = {
    problem = { color = "gray, brown", mono = "reverse" },
    current_problem = { color = "yellow, red; underline", mono = "reverse+underline" },
  }
}

-------------------------------- The registry --------------------------------

M.primary_checkers = {

  ['XML document'] = {
    prog = 'xmllint --noout "%s" 2>&1',
    pattern = ':(%d+):'
  },

  ['C Program'] = {
    prog = 'cppcheck --enable=all --inconclusive --std=posix "%s" 2>&1',
    pattern = ':(%d+)]'
    -- @todo: Have a look at OCLint.
  },

  ['Ruby Program'] = {
    alternatives = {
      {
        test = 'ruby-lint --help',
        prog = 'ruby-lint analyze "%s"',
        pattern = 'line (%d+)'
      },
      -- We prefer "ruby2.0" to [possibly] older "ruby" because it handles "-wc" better. See:
      --    http://stackoverflow.com/questions/1805146/where-can-i-find-an-actively-developed-lint-tool-for-ruby
      {
        test = 'ruby2.0 --version',
        -- To prevent Ruby 1.9 from complaining about UTF-8 sources, we add "-Ku".
        -- (which Ruby 1.8 too accepts.)
        prog = 'ruby2.0 -Ku -wc "%s" 2>&1',
        pattern = ':(%d+):'
      },
      {
        test = 'ruby --version',
        prog = 'ruby -Ku -wc "%s" 2>&1',
        pattern = ':(%d+):'
      }
    }
  },

  ['Python Program'] = {
    prog = 'pyflakes "%s" 2>&1',
    pattern = ':(%d+):'
    -- ERROR example:  youtube-dl.py:592: local variable 'err' is assigned to but never used

    -- @todo: Have a look at flake8.
  },

  ['PHP Program'] = {
    prog = 'php -l "%s" 2>&1',
    pattern = 'line (%d+)'
    -- ERROR example:  PHP Parse error:  syntax error, unexpected ')' in aa.php on line 3
  },

  ['JavaScript Program'] = {
    alternatives = {
      {
        test = 'jshint --help',
        prog = 'jshint "%s"',
        pattern = 'line (%d+)'
        -- ERROR example:  t.js: line 4, col 10, Missing semicolon.
      },
      {
        test = 'jslint.js /dev/null',
        prog = 'jslint.js --white true --terse "%s"',
        pattern = ':(%d+):'
        -- ERROR example:
        --   t.js:2:15: Unused 'c'.
        --   (line 2, char 15)
      }
    }
  },

  ['Lua Program'] = {
    alternatives = {
      {
        -- See: http://lua-users.org/wiki/LuaLint
        --   (linked from: http://lua-users.org/wiki/DetectingUndefinedVariables)
        test = "lualint",
        prog = [[lualint '%s' 2>&1 |
                  grep -v 'global get of \(devel\|fs\|mc\|timer\|event\|fields\|regex\|tty\|ui\|keymap\|keymap\|utils\|prompts\|conf\|luafs\|package\|T\|N\|Q\|E\|alert\|abort\|abortive\|assert_arg_type\|autoload\|import_from\)$' |
                  grep -v 'could not find imported module' |
                  grep -v 'did not successfully parse' ]],
        pattern = ':(%d+):'
      },
      {
        test = 'luac -v',
        prog = 'luac -p "%s" 2>&1',
        pattern = ':(%d+):'
        -- ERROR example:  luac: sc.lua:8: '=' expected near 'print'
      }

      -- @todo: We might also want to consider:
      -- * luacheck (https://github.com/mpeterv/luacheck) seems good!
      -- * LuaInspect, TypedLua (linked from SO #28281475).
    }
  },

  ['Perl Program'] = {
    prog = 'perl -c "%s" 2>&1 > /dev/null',  -- Capture only STDERR. Throw away STDOUT.
    pattern = "line (%d+)"
  }

}

--
-- An alternative registry used for disassemblers.
--

M.secondary_checkers = {

  -- We want to show all of a disassembler's output, as it may contain comments,
  -- so we use the 'show_all_lines' flag.

  ['Lua Program'] = {
    alternatives = {
      {
        test = 'luacexplain /dev/null && luac -v',
        prog = 'luac -l -l -p "%s" 2>&1 | luacexplain | expand',
        pattern = '%[(%d+)%]',
      },
      {
        test = 'luac -v',
        prog = 'luac -l -l -p "%s" 2>&1 | expand',  -- '-p' prevents it from writing 'luac.out'.
        pattern = '%[(%d+)%]',
        -- Line example:  "  90   [156]   SETTABLE    6 -16 -51"
      },
    },
    show_all_lines = true,
    jump_to_current_line = true,
  },

  ['Python Program'] = {
    -- This is mainly for demonstration. What we're doing here isn't quite
    -- practical: it disassembles the top-level only; it doesn't descend into
    -- functions and classes.
    prog = 'python -m dis "%s" 2>&1',
    pattern = '^%s?%s?(%d+)',
    -- Line example: "  35    98 LOAD_NAME     8 (...)"
    show_all_lines = true,
    jump_to_current_line = true,
  },

}

M.aliases = {
  ['C/C++ Program'] = 'C Program',
  ['LUA Program'] = 'Lua Program',  -- Backward-compatibility: old 'mcedit/Syntax' files may still incorrectly call the language "LUA".
}

------------------------------- Lint selector --------------------------------

local select_program__with_message = import_from('samples.libs.os', { 'select_program__with_message' })

--
-- Selects the lint program to use.
--
local function select_program(checker)

  if checker.prog then
    return true
  end

  -- For checkers that have several programs associated with them,
  -- we select the first program found on the system:
  local suit, errmsg = select_program__with_message(checker.alternatives, T"Lint: I can't check your code.")
  if suit then
    checker.prog = assert(suit.prog)
    checker.pattern = assert(suit.pattern)
    return true
  else
    return nil, errmsg
  end

end

--------------------------------- Da Brain! ----------------------------------

--
-- The "brain" of this script.
--
-- This function gets the file's path and syntax name and returns a list
-- of "problems" it found in it.
--
-- Returns the pair (nil, errmsg) on error.
--
function M.lint(filename, checkers, syntax)

  local problems = {}
  local successful_exit = false

  local checker = checkers[syntax] or checkers[M.aliases[syntax]]

  if not checker then
    return nil, T"Lint: I don't know how to handle '%s'":format(syntax)
  end

  if not select_program(checker) then
    return select_program(checker)  -- Returns (nil, errmsg)
  end

  -- Note: Lua 5.2+'s file:close() can tell us if the program popen()'ed existed
  -- successfully. But since we have to support Lau 5.1, we resort to planting in
  -- the command a sentinel string which we'll be watching for.
  local cmd = checker.prog:format(filename) .. " && echo Successful Exit"
  local pattern = assert(checker.pattern)

  local f = io.popen(cmd, "r")
  for line in f:lines() do
    local line_no = line:match(pattern)
    if line_no or checker.show_all_lines then
      append(problems, { line:gsub(filename:gsub('%W', '%%%0'), '<file>'), value = {
        line_no = tonumber(line_no)  -- We can't store nils in tables, so we don't assign directly to 'value'.
      }})
    end
    if not line_no then
      if line:find("Successful Exit") then
        successful_exit = true
      end
    end
  end
  f:close()

  if #problems == 0 and not successful_exit then
    return nil, T"Lint: I couldn't run the command: \n\n %s \n\nPerhaps the program isn't installed?":format(cmd)
  end

  return problems, nil, checker

end

----------------------------------- The UI -----------------------------------

function M.run(checkers)

  checkers = checkers or M.primary_checkers

  local ed = assert(ui.current_widget("Editbox"))

  if ed.modified then
    abort(T'Save the file first.')
  end

  if not ed.filename then
    abort(T'Save the file first. It has to be a file on disk so the lint program can read it.')
  end

  if not ed.syntax then
    abort(T"This file doesn't have an associated syntax. I can't lint programs of unknown syntax.")
  end

  -- Compile the styles.
  local style = utils.table.map(M.style, tty.style)

  -- Clear all the bookmarks from the previous run.
  ed:bookmark_flush(style.problem)
  ed:bookmark_flush(style.current_problem)

  -- We have to use fs.getlocalcopy() as the file may reside in a zip archive, for example.
  local local_pathname = fs.getlocalcopy(ed.filename)
  local problems, errmsg, checker = require('prompts').please_wait(T"Executing the appropriate lint program for this file.", M.lint, local_pathname, checkers, ed.syntax)
  fs.ungetlocalcopy("<unneeded>", local_pathname, false)

  if errmsg then
    abort(errmsg)
  end

  if #problems == 0 then
    alert(T"All's fine.")
    return
  end

  -- Highlight (bookmark) all the problematic lines.
  if not checker.show_all_lines then
    for _, problem in ipairs(problems) do
      ed:bookmark_set(problem.value.line_no, style.problem)
    end
  end

  local dlg = ui.Dialog{T"Problems for %s":format(ed.filename), compact = true}

  local list = ui.Listbox()
  list.items = problems
  list.on_change = function(self)
    ed:bookmark_flush(style.current_problem)
    if self.value.line_no then  -- can be nil if checker has 'show_all_lines'.
      ed.cursor_line = self.value.line_no
      ed:bookmark_set(self.value.line_no, style.current_problem)
    end
    dlg:refresh(true)  -- redraw the dialog on top of the editor.
  end

  -- Jump to the "problem" for the line we're standing on. Useful for disassemblers.
  if checker.jump_to_current_line then
    for i = 1, #problems do
      if problems[i].value.line_no == ed.cursor_line then
        list.selected_index = i
        break
      end
    end
  end

  list:on_change()

  dlg:add(list)
    :set_dimensions(0, tty.get_rows() - dlg:preferred_rows() - 1, tty.get_cols())
    :run()

end

------------------------------------------------------------------------------

return M
