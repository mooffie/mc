---
-- Common dialog boxes.
--
-- @module prompts

local prompts = require("c.prompts")

---
-- Asks the user for input to type.
--
--    local age = prompts.input(T"What's your age?")
--    local lang = prompts.input(T"What's you mother tongue?", "English")
--    local food = prompts.input(T"What did you eat today?", -1, nil, "foods")
--
-- You may provide a **default** value to initialize the input with. The special
-- value `-1` initializes the input with the last value from the history.
--
-- The strings typed are kept in a shared history. If you wish your dialog to
-- have a private history, provide some unique **history** string.
--
-- If the user cancels the dialog, the function returns **nil**. This
-- is different than not typing any input, in which case an empty string is returned.
--
-- - This function is @{mc.is_background|background}-safe.
-- - You may use this function even when the UI is @{tty.is_ui_ready|not ready}:
--   the user will be asked to enter input through the raw terminal.
--
-- @function input
-- @args (question, [default], [title], [history])

-- Note: the 'question' param is actually optional.
function prompts.input(question, default, title, history, is_password)
  if tty.is_ui_ready() then
    return prompts._input(question, default, title, history, is_password)
  else
    if title then
      print("[" .. title .. "]")
    end
    question = question or T"Enter input:"
    print((question:gsub("([^:])$", "%1:")))   -- Ensure it ends with ":"
    if is_password then
      print(T"(Warning: anything you type will be echoed!)")
    end
    return io.read()
  end
end

---
-- Asks the user for password.
--
-- Return the user input, or **nil** is the user cancels the dialog.
--
--    if prompts.get_password(T"Type the password for launching the A-bomb") == "top secret" then
--      launch_missile()
--    end
--
-- - This function is @{mc.is_background|background}-safe.
-- - You may use this function even when the UI is @{tty.is_ui_ready|not ready}:
--   the user will be asked to enter input through the raw terminal.
--
-- @function get_password
-- @args ([message])
function prompts.get_password(message)
  return prompts.input(T"Password:", nil, message, nil, true)
end

return prompts
