--
-- The :help command.
--

local colon = require('samples.colon')

local List = utils.table.List

local prolog = T[[
This tool lets you execute "colon" commands (a concept you may be
familiar with from the Vi editor).

Commands are of the form ":command_name [args]", and are typed on the
filemanager's command line, or in the editor after pressing M-x.

Here are the available commands:
]]

local epilog = T[[
(The set of available commands depends on whether you're in the
filemanager or in the editor. More commands may be available by
require()'ing extra modules.)
]]

local function indent(s, indent)
  return indent .. s:gsub("\n", "\n" .. indent)
end

local function describe_command(cmd)
  local headers = indent(cmd.synopsis or cmd.name, ':')
  local body = indent(cmd.desc or T"No description.", '    ')
  return headers .. "\n" .. body
end

local function cmd_help(context)

  local context_type = context and context.widget_type

  local registry = List( colon.commands_iterator() )

  local cmds = registry:filter(function(cmd) return cmd.context_type == context_type or not cmd.context_type end)

  local cmds_rendering = cmds:map(describe_command):concat("\n\n")

  local help = prolog .. "\n" .. indent(cmds_rendering, '  ') .. "\n\n" .. epilog

  devel.view(help, tostring)  -- A trick to launch the viewer (until we implement mc.view_string()).

end

colon.register_command {
  name = "help",
  alias = "h",
  synopsis =
    "help\n" ..
    "h",
  fn = cmd_help,
  desc = T[[
Shows a help screen listing the available commands.]]
}
