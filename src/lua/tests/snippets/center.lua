--[[

Centers a line.

Used to created headers and separators in Lua sources. E.g.,
turns the line "Functions" into "----- Functions -----" (padded to 78 columns).

]]

local WD = 78

ui.Editbox.bind('C-c c', function(edt)

  local ln = edt.line
  local indent = ln:match '^%s*'
  local gist = ln:p_match [[^\s*-*\s*(.*?)\s*-*$]]

  local half = math.floor(
                 ( (WD - indent:len()) - gist:len() - 2 )
                 / 2
               )
  local dashes = string.rep('-', half)
  if gist ~= '' then
    ln = indent .. dashes .. ' ' .. gist .. ' ' .. dashes
  else
    ln = indent
  end
  ln = ln .. string.rep('-', WD - ln:len())

  edt:command 'DeleteLine'
  edt:insert(ln .. "\n")

end)
