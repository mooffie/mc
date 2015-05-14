-- Demonstrates some 'errno' bugs.

--[[

mc_open() (in lib/vfs/interface.c) returns "-EOPNOTSUPP" for unrecognized
filesystems (or when open() isn't supported for a filesystem).

(1) Why negative?! Seems like a mistake. (And as a side-effect, we report it as a useless "Unknown error -95" ...)

(2) It should be E_NOTSUPP (defined in vfs.h). "EOPNOTSUPP" is for sockets.

]]

local posix = require "fs.filedes"

print( posix.open("/invalidfs://whatever.txt") )

--[[

Another bug: chdir() to an invalid filesystem reports the previous errno.

]]

assert(io.popen("ls -l"), "pipes aren't supported on this sys"):seek("end")  -- set the errno to "Illegal seek"

print( fs.chdir("/invalidfs://") )  -- chdir() reports "Illegal seek"!
