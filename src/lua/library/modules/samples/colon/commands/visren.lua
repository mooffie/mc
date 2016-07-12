--
-- VisRen commands.
--

local colon = require('samples.colon')

--
-- Parses the "/search/replace/i" argument.
--
-- Returns (search-string, replace-string, global?, ignore-case?),
-- or nothing on error.
--
local function parse(s)
  local a, b, c, d = s:p_match{ [[
                ^
                ([-!@#$%^&*_=+|:;'",./?])  # a = separator
                (.*?)                      # b = search
                \1
                (.*?)                      # c = replace
                ( \1 [gi]* )?              # d = flags
                $
    ]], 'x' }
  if a then
    local global      = d and d:find 'g' and true or false
    local ignore_case = d and d:find 'i' and true or false
    return b, c, global, ignore_case
  end
end

local function test_parse()

  local ensure = devel.ensure

  local f = false
  local T = true

  local tests = {
    { '/one/two',        { 'one', 'two', f, f } },
    { '/one/two/',       { 'one', 'two', f, f } },
    {'/one/two/three',   { 'one', 'two/three', f, f } },
    { '/one/two/gi',     { 'one', 'two', T, T } },
    { '/one',            { } },  -- invalid
    { '/one/',           { 'one', '', f, f } },
    { '/one//g',         { 'one', '', T, f } },
    { '/one//i',         { 'one', '', f, T } },
    { '//',              { '', '', f, f } },
  }

  for i, test in ipairs(tests) do
    ensure.equal( { parse(test[1]) }, test[2], 'test' .. i )
  end

end

local function cmd_visren(pnl, args)
  local a, b, global, ignore_case = parse(args)
  abortive(a, T"Invalid command syntax. Example: s/\\.htm$/.html/")
  require('samples.apps.visren').run {
    input = a,
    template = b,
    global = global,
    ignore_case = ignore_case
  }
end

colon.register_command {
  name = 's',
  content_type = 'Panel',
  raw_args = true,  -- We don't want Colon to tokenize the args.
  synopsis =
    "s/search/replace[/flags]",
  fn = cmd_visren,
  desc = T[[
Rename files.
This launches Visual Rename, where you can inspect the changes before
committing them.
Note: The command works on the *selected* files only, or on the current
file if none is selected. If you want to rename all the files in the
directory, select all the files first.
Example:
     s/\.jpe?g$/.jpg/i
Possible flags are 'g' (global) and 'i' (ignore case).]],
}
