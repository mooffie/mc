---
-- @module devel

local M = {}

local initialized = false
local f

---
-- Logs a message.
--
-- This only works if the environment variable `MC_LUA_LOG_FILE` contains a
-- path of a file you want to serve as the log file. Otherwise, this function
-- does nothing.
--
-- The output to the log file isn't buffered: it will be written out
-- immediately.
--
function M.log(msg)

  if not initialized then
    local log_file = os.getenv("MC_LUA_LOG_FILE")
    if log_file then
      f = io.open(log_file, "a")
      f:setvbuf("no")
    end
    initialized = true
  end

  if f then
    f:write(tostring(msg), "\n")
  end

end

return M
