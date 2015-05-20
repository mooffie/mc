
local ensure = devel.ensure

local fs_glob_mdl = require('fs.glob')
local tglob = fs.tglob
local glob = fs.glob
local fnmatch = fs.fnmatch
local glob_to_replacement = import_from('utils.glob', {'glob_to_replacement'})

local function test_glob()

  fs_glob_mdl.internal_tests()

  ensure.equal(tglob('/etc/fs[t]ab'), {'/etc/fstab'}, 'sanity check')  -- we should create a mock filesystem instead.
  ensure.equal(tglob('/non-existant/*'), {}, 'missing dir')
  ensure.throws(function()
    tglob('/non-existant/*', {fail=true})
  end, nil, 'missing dir raises error')

end

local function test_fnmatch()

  ensure(fnmatch("*.{gif,pcx}","pic.gif"), "fnmatch #1")
  ensure(fnmatch("**/clip.o","one/clip.o"), "fnmatch #2")
  ensure(fnmatch("**/clip.o","clip.o"), "fnmatch #3")
  ensure(not fnmatch("**/clip.o","WHATEVERclip.o"), "fnmatch #4")

end

local function test_others()

  ensure.equal(glob_to_replacement [[fi\*le*.htm?]], [[fi*le\1.htm\2]], "glob_to_replacement")

end

test_glob()
test_fnmatch()
test_others()
