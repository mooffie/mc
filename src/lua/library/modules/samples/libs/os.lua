--[[

OS utilities.

]]

local M = {}

---
-- Figures out if a program is installed (by trying to run it).
--
-- Argument **cmd** is often just the program name. Sometimes (as in git)
-- the program would expect *some* argument on the command line (or else
-- report error). You can get away with this, in git's case for example,
-- by passing "git --version". Each program has its own rules.
--
-- STDIN, STDOUT, and STDERR are all redirected to /dev/null.
function M.try_program(cmd)
  local full = cmd .. " < /dev/null > /dev/null 2>&1"
  devel.log("Checking for a program availability by running: " .. full)
  local res = os.execute(full)
  -- "== true" is for Lua 5.3
  -- "== 0" is for olders.
  return (res == 0) or (res == true)
end

---
-- Sometimes several programs can perform a task and we need to select the
-- first one that's installed on the system.
--
-- This function accepts a table of the form...
--
--    {
--      {
--        test="somecommand -v",
--        ...
--      },
--      {
--        test="othercommand --help",
--        ...
--      },
--      ..
--    }
--
-- ...and returns the first sub-table whose 'test' command runs successfully.
-- if non found, returns the pair (nil, error_mesage) (so you can wrap it in
-- abort()).
--
-- since the programs are tried in order, you should sort the entries from
-- the most desired to the least desired.
--
function M.select_program__with_message(alternatives, msg)
  local found, failures = M.select_program(alternatives)
  if not found then
    msg = msg or T"I can't carry out this task."
    return nil,
      msg .. "\n\n" ..
        T"To carry out this task I need you to have any of the following programs installed:\n  %s\nYou have none.":format(failures)
  else
    return found
  end
end

function M.select_program(alternatives)
  local failures = {}
  for _, try in ipairs(alternatives) do
    if M.try_program(try.test) then
      return try
    else
      table.insert(failures, try.test:match '%S+')
    end
  end
  return nil, table.concat(failures, ", ")
end

return M
