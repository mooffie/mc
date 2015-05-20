
local magic = require('utils.magic')

local ensure = devel.ensure

local function test_strict()

  local t = {
    one = true,
    two = true,
  }

  magic.setup_strict(t, true, true)

  assert(t.one)
  ensure.throws(function() return t.missing end, nil, "strict read")
  ensure.throws(function() t.missing = 666 end, nil, "strict write")

  magic.setup_strict(t, false, false)    -- Turn everything off.

  assert(not t.non_existent, "non-strict read")

  t.non_existent = 666
  assert(true, "non-strict write")

end

test_strict()
