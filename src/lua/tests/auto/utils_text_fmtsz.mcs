
local ensure = devel.ensure

-- We can't do 'os.setlocale("C")' because the flag 'numeric_locale_is_posix' in our locale module
-- has already been set.
assert(os.setlocale() == "C" or os.setlocale():find "en_", "You must run this test in the POSIX/C locale.")

local format_size = require('utils.text').format_size

local function test()

  local check = function(sz, cols, expected, comma)
    ensure.equal(format_size(sz, cols, comma), expected, expected)
  end

  check(123456789, 9, "123456789")
  check(123456789, 9, "120,563K", true)
  check(123456789, 5, "118M")

end

test()
