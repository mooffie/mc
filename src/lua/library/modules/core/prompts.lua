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

local function create_buttons(list)
  local btns = ui.Buttons()
  for _, item in ipairs(list) do
    assert(type(item) == "table", E"An item must be a table")
    btns:add(ui.Button{item[1], result=(item[2] or false)})
  end
  return btns
end

---
-- Queries the user for a choice.
--
-- Displays possible choices for the users, as buttons.
--
--    local answer = prompts.query(Y"Do it?", {
--      {T"Yes", "yes"},
--      {T"Maybe", "maybe"},
--      {T"No"}
--    }) or "no"
--
-- (Note how we equate the "No" button with pressing ESC by doing `or "no"`.)
--
-- The title, if provided, is passed as-is to ui.Dialog(), so if you want an
-- error dialog, do:
--
--    local answer = prompts.query({T"Important question", colorset="alarm"},
--      Y"Do it?", {
--        ...
--      })
--
-- See more examples @{git:fileops/contexts/interactive.lua|here}.
--
-- @function query
--
-- @args ([title,] question, answers)
-- @param title Optional title for the dialog.
-- @param question A string.
-- @param answers A list of possible answers. Will be shown as buttons.
--  Each answer is a list: its first element is the label and its second
--  (optional) element is the result value.
function prompts.query(title, question, answers)
  if answers == nil then
    answers = question
    question = title
    title = ""
  end
  assert(type(answers) == "table" and type(question) == "string", E"Invalid query() arguments")

  if not tty.is_ui_ready() and not mc.is_standalone() then
    error(E"This function can't be used when the UI is not yet ready.")
  end

  local bor = require("utils.bit32").bor
  local dlg = ui.Dialog(title)

  dlg:add(ui.Label{question, pos_flags = bor(ui.WPOS_CENTER_HORZ, ui.WPOS_KEEP_TOP)})
  dlg:add(create_buttons(answers))

  return dlg:run()
end

---
-- Shows a "Please wait" sign for a potentially lengthy operation.
--
-- This function runs some code, specified by the *callback* parameter, and while doing
-- this it shows a "Please wait" dialog.
--
-- Use this function when running a long task (e.g., when using
-- @{os.execute} or @{io.popen}) so your user knows why he has to incur the delay.
--
-- (Alternatively, instead of using this function, split your lengthy task
-- into smaller slices and run them in a timer/thread. This will keep the
-- UI responsive.)
--
--    prompts.please_wait(T"Searching for UnicodeData.txt file.", function()
--      unicodedata_path = io.popen("locate -n 1 -e /UnicodeData.txt"):read()
--    end)
--
-- This function returns the *callback*'s result. So you can replace any:
--
--    one, two, three = func(four, five)
--
-- with:
--
--    one, two, three = prompts.please_wait(T"Doing something", func, four, five)
--
-- - This function is @{mc.is_background|background}-safe.
-- - You may use this function when the UI is @{tty.is_ui_ready|not ready}.
--
-- @args (message, callback[, ...])
--
function prompts.please_wait(message, callback, ...)

  assert_arg_type(1, message, "string")
  assert_arg_type(2, callback, "function")

  if not tty.is_ui_ready() or mc.is_background() then
    if not tty.is_ui_ready() then
      print(message .. "  " .. T"Please wait...")
    end
    return callback(...)
  end

  local dlg = ui.Dialog(T"Please wait...")
  dlg:add(ui.Label(message))

  local args = { ... }
  local results

  -- A pending <F10> may cause the dialog to be closed before
  -- we even call the callback, so we disable closing:
  dlg.on_validate = function()
    return false
  end

  -- We can't use on_init: (1) the dialog isn't yet DLG_ACTIVE there, which
  -- means we can't show it; (2) and we can't close it. See ldoc for on_init.
  dlg.on_idle = function()

    dlg.on_idle = nil  -- We don't want to be called more than once. See ldoc for on_idle.

    -- The following line has two reasons:
    --
    -- * In case an exception is raised in the callback, we want the user to
    --   be able to close this dialog.
    --
    -- * While MC ignores on_validate when closing the dialog via on_idle (see
    --   luadoc for on_validate), this is a feature that, who knows, might
    --   be removed in the future(?).
    dlg.on_validate = nil

    tty.refresh()
    results = { callback(table.unpackn(args)) }
    dlg:close()
  end

  dlg:run()

  -- We may be followed by non UI-yielding lengthy calculation, so tell the
  -- terminal to paint over the dialog right now:
  tty.refresh()

  if not results then return end  -- 'results' is nil if an exception is raised inside 'callback'.

  return table.unpackn(results)
end

---
-- Posts a message on the screen for a brief time.
--
-- The user can dismiss the message earlier by hitting any key.
--
-- Don't use this device for critical messages: it isn't considered
-- good usability.
--
-- If the amount of time, **msec**, isn't specified, it will be calculated
-- for you based on the length of the message.
--
-- @function flash
-- @args (message[, msec])
function prompts.flash(message, msec)

  msec = msec or (
    -- Default calculation:
    --
    -- For every character we add 25 msec.
    -- "Green men from mars" runs for about 1300 msec.
    820 + 25 * tty.text_width(message)
  )

  local sleep = require('internal')._sleep
  local first_time = true
  local dlg = ui.Dialog()

  dlg:add(ui.Label(message))

  -- A dialog can't be closed using set_timeout() (see comment explaining
  -- why at dialog:on_init's ldoc). We have to use sleep(), which we break
  -- into many short sleep()s to allow the user to exit earlier.

  dlg.on_idle = function()

    if first_time then
      tty.refresh()
      first_time = false
    end

    if msec > 0 then
      sleep(100)
      msec = msec - 100
    else
      dlg.on_idle = nil  -- Don't call us again.
      dlg:close()
    end

  end

  -- We want any key to close the dialog. Not just ESC/enter.
  dlg.on_key = function()
    dlg:close()
  end

  dlg:run()

  tty.refresh()   -- See expl. in plase_wait().

end

-- Like alert() but returns immediately.
--
-- The message stays on the screen till the next tty.refresh().
--
-- (Since end-users are unlikely to need this, we don't ldoc-document it.)
--
function prompts.post(message)
  local dlg = ui.Dialog()
  dlg:add(ui.Label(message))
  dlg.on_idle = function()
    tty.refresh()
    dlg.on_idle = nil
    dlg:close()
  end
  dlg:run()
end

return prompts
