--[[

This example shows how to write a filesystem that simply delegates
everything to some other filesystem.

Accessing "mirror://" will show you your home dir.

]]

-- You may change this to whatever you want. It doesn't have to be a localfs.
local base = assert(os.getenv("HOME")) .. "/"

-- Base must be an absolute path. Otherwise we might cause infinite recursion
-- as we might (depending on cwd) end up inside the "mirror" url-space again.
assert(base:sub(1,1) == "/", "base path must be absolute.")

local myfs = {

  prefix = "mirror",

  stat = function(_, path)
    return fs.stat(base .. path)
  end,
  lstat = function(_, path)
    return fs.lstat(base .. path)
  end,
  chmod = function(_, path, mode)
    return fs.chmod(base .. path, mode)
  end,
  utime = function(_, path, modtime, actime)
    return fs.utime(base .. path, modtime, actime)
  end,
  chown = function(_, path, owner, group)
    return fs.chown(base .. path, owner, group)
  end,
  link = function (_, p1, p2)
    return fs.link(base .. p1, base .. p2)
  end,
  readlink = function (_, path)
    return fs.readlink(base .. path)
  end,
  unlink = function(_, path)
    return fs.unlink(base .. path)
  end,
  mkdir = function(_, path)
    return fs.mkdir(base .. path)
  end,
  rmdir = function(_, path)
    return fs.rmdir(base .. path)
  end,

  open = function(_, path, mode, info)
    -- Doing 'fs.open(base .. path, mode)' would work, but the following
    -- is more accurate.
    return fs.open(base .. path, info.mc_flags, info.creation_mode)
  end,
  read = function(_, fh, count)
    return fh:read(count)
  end,
  write = function(_, fh, buf)
    return fh:write(buf)
  end,
  seek = function(_, fh, whence, offs)
    return fh:seek(whence, offs)
  end,
  fstat = function(_, fh)
    return fh:stat()
  end,
  close = function(_, fh)
    return fh:close()
  end,

  rename = function (_, p1, p2)
    return fs.rename(base .. p1, base .. p2)
  end,
  symlink = function (_, p1, p2)
    return fs.symlink(p1, base .. p2)
  end,
  readdir = function(_, path)
    return fs.dir(base .. path)
  end,
  chdir = function(_, path)
    return fs.chdir(base .. path)
  end,
  mknod = function(_, path, mode, dev)
    return fs.mknod(base .. path, mode, dev)
  end,

  -- In the future, if we let Lua filesystem implement "(un)getlocalcopy"
  -- (see a comment in luafs.c), we'll delegate it too to the target
  -- filesystem. In our case, if the target is localfs, the benefit would be
  -- getting rid of the temp files (in /tmp) when you hit ENTER on an image,
  -- for example.
}

fs.register_filesystem(myfs)
