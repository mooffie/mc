---
-- Functions for writing tests.
--
-- These functions write messages to stdout, so it's natural
-- to run tests using `mcscript`.
--
-- Example:
--
--    local ensure = devel.ensure
--
--    ensure(4 > 3, "Basic math")
--    ensure.equal(utils.text.parse_size("4KB"), 4000, "parse_size()")
--
-- Tip-short: For more examples, see the test scripts in the folder @{git:lua/tests/auto}.
--
-- @module devel.ensure

local M = {}

---
-- Tests a condition.
--
--    local ensure = devel.ensure
--    ensure.ok(4 > 3, "Basic math")
--
-- [info]
--
-- Since this test is so elementary, it's possible to use a shorter syntax:
--
--    local ensure = devel.ensure
--    ensure(4 > 3, "Basic math")
--
-- [/info]
--
function M.ok(cond, msg)
  if cond then
    print(msg .. "   - OK")
  else
    error(E"Failed to ensure: %s":format(msg), 2)
  end
end

local function throws(f, needle)
  local ok, errmsg = pcall(f)
  if not ok then
    if needle then
      if errmsg:find(needle, 1, true) then
        return true
      end
    else
      return true
    end
  end
end

---
-- Tests that some code throws exception.
--
--    local ensure = devel.ensure
--
--    ensure.throws(function()
--      -- A pattern cannot start with a star!
--      regex.compile "*"
--    end, nil, "Invalid regex pattern throws error")
--
-- The **needle** argument, if provided, is a sub-string to ensure appears in the exception message.
--
function M.throws(f, needle, msg)
  M.ok(throws(f, needle), msg)
end

---
-- Tests that some code does not throw exception.
function M.does_not_throw(f, msg)
  M.ok(not throws(f), msg)
end

-- Make is possible to write ensure(...) instead of ensure.ok(...)
setmetatable(M, {
  __call = function(t, ...)
    M.ok(...)
  end
})

return M
