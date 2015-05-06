
-- Tests the "stamps" mechanism, which is how the VFS layer keeps track
-- of filesystems that can be freed.

-- To run this test you need to enable 'luafs_markdown.lua'.

------------------------------------------------------------------------------

fs.open('/tmp/test.md', 'w'):write [[
# hello
Hi there!
]] : close()

------------------------------------------------------------------------------

keymap.bind('C-u 1', function()
  assert(fs.dir(
    "/tmp/test.md/markdown://"
  ))

  alert([[
A markdown FS has been accessed.
You'll see it in your Active VFS dialog (C-x a).
It will be freed in about 60 seconds (unless you 'free' it even sooner).]])
end)

------------------------------------------------------------------------------

local f

keymap.bind('C-u 2', function()
  f = assert(fs.open("/tmp/test.md/markdown://001. hello"))
  alert([[
A file on the markdown FS is now open.
Try as you may, you won't be able to free the FS till you close that file.]])
end)

keymap.bind('C-u 3', function()
  if not f then return end
  f:close()
  alert([[
The file has been closed.
You'll now be able to free the FS.]])
end)

------------------------------------------------------------------------------

--
-- This lets you see the stamps, if you're curious.
--
-- See documentation at luafs.c:l_get_vfs_stamps() for explanation.
--
keymap.bind('C-u 4', function()
  devel.view(require('luafs.gc').get_vfs_stamps())
end)

------------------------------------------------------------------------------
