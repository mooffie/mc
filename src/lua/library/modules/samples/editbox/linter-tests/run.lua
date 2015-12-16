#!/usr/bin/env mcscript

local linter = require('samples.editbox.linter')

local dir = "data/"
local tests = {
  { "a.php", "PHP Program" },
  { "l.lua", "Lua Program" },
  { "p.pl", "Perl Program" },
  { "r.rb", "Ruby Program" },
  { "t.js", "JavaScript Program" },
  { "q.py", "Python Program" },
}

local function run_tests()
  for _, test in ipairs(tests) do
    local file, syntax = table.unpack(test)
    file = dir .. file

    local problems, errmsg = linter.lint(file, linter.primary_checkers, syntax)
    assert(not errmsg, errmsg)
    devel.view({syntax, problems})
  end
end

run_tests()
