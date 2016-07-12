--[[

This module lets you execute ex-style commands, in the filemanager and in
the editor.

To learn of the available commands, type :help in the filemanager (or in
the editor, after M-x).

The 'commands' subdir contain some example commands. Browse them to learn
how to write your own.

]]

local List = utils.table.List

----------------------------- Commands registry ------------------------------

local M = {}

local registry = List {

  --
  -- The commands are kept here. Here's a command example:
  --
  -- {
  --   name = 'spell',
  --   context_type = 'Editbox',
  --   fn = function(edt)
  --     require('samples.editbox.speller').check_file(edt)
  --   end,
  --   desc = T"Spell-checks the document."
  -- }
  --
  -- Use register_command() to add commands.
  --
}

function M.register_command(cmd)
  registry:insert(cmd)
end

local function find_command(name, context_type)
  for _, cmd in ipairs(registry) do
    if (cmd.name == name or cmd.alias == name) and (cmd.context_type == context_type or not cmd.context_type) then
      return cmd
    end
  end
end

-- The :help command needs access to all commands. We expose them with this module-level function.
function M.commands_iterator()
  return registry:iterate()
end

---------------------------------- Parsing -----------------------------------

local COMMAND_NAME= '[%w_.-]+'

--
-- Parses a command string.
--
-- Returns two values: the command name, and its arguments.
--
-- Example: given ":one two three", returns ("one", "two three").
--
local function parse_raw_command(s)
  s = s:gsub('^%s*:*%s*', '')  -- Remove the optional ":" prefix.
  local cmd, raw_args = s:match( '^(' .. COMMAND_NAME ..')%s*(.-)%s*$' )
  return cmd, raw_args
end

local function test__parse_raw_command()

  local ensure = devel.ensure

  local tests = {
    { ' : one  two three ',  { 'one', 'two three' } },
    { ':s/one/two/g',        { 's', '/one/two/g' } },
    { ':one   ',             { 'one', '' } },
    { ':   ',                { } },
    { ': , ',                { } },
  }

  for i, test in ipairs(tests) do
    ensure.equal( { parse_raw_command(test[1]) }, test[2], 'test' .. i )
  end

end

------------------------------------------------------------------------------

function M.execute_raw_command(s, context)

  local cmd_name, raw_args = parse_raw_command(s)
  if not cmd_name then
    abort(T"Invalid command syntax. The syntax is:\n\n       :command_name [args]\n\nType :help for more.")
  end

  local cmd = find_command(cmd_name, context and context.widget_type)
  if not cmd then
    abort(T"I don't recognize the command '%s'. Try :help.":format(cmd_name))
  end

  local args
  if cmd.raw_args then
    args = { raw_args }
  else
    local err_msg
    args, err_msg = utils.text.shell_split(raw_args)
    if err_msg then
      abort(T"Quoting error:\n%s":format(err_msg))
    end
  end

  table.insert(args, 1, context or false)  -- 'false', as tables can't store 'nil'.

  cmd.fn(table.unpack(args))

end

---------------------------------- Bindings ----------------------------------

--
-- Detects :colon commands typed in the filemanager and executes them.
--
ui.Panel.bind('enter', function(pnl)
  local ipt = ui.current_widget('Input')
  if ipt and ipt.text:find '^%s*:' then
    M.execute_raw_command(ipt.text, pnl)
    ipt:command "HistoryNext"  -- a trick to push it into history.
    ipt.text = ""
  else
    return false
  end
end)

--
-- Prompts for input in the editor and executes the command typed.
--
ui.Editbox.bind('M-x', function(edt)
  local s = prompts.input(T"Enter some command (you don't need to start it with ':')", "help",
                          T"Command", "colon-editbox-commands")
  if s then
    M.execute_raw_command(s, edt)
  end
end)

------------------------------------------------------------------------------
--
-- Load a few sample commands. Since these samples require() this module,
-- we have a circular dependency here. We solve it by assigning to
-- package.loaded[this_module_name] early on.
--
package.loaded[...] = M  -- the '...' equals module name.
require('samples.colon.defaults')

------------------------------------------------------------------------------

return M
