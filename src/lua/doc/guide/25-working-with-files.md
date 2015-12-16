
# Working with files

MC is a filemanager. Its audience is system administrators and people
who like to tinker with the filesystem. It's only natural that you'd
want access in your scripts to file manipulation functions.

The @{fs} module provide all the lower level functions, POSIX-like,
you'd normally expect. The @{mc} module provides a few higher-level
functions (like copying files and directories).

Let's print the first line of every text file in the home directory:

    local pattern = "/home/mooffie/Documents/**/*.txt"
    for fname in fs.glob(pattern) do
      local f = assert(fs.open(fname))
      print(f:read("*l"))
      f:close()
    end

    -- (Note: we can shorten this code by using fs.read().)

Nothing very exciting here, is it?

Now, what it we wanted to print the first line of every text file is some archive?

Easy:

    local pattern = "/home/mooffie/inti.tar.gz/utar://**/*.txt"
    for fname in fs.glob(pattern) do
      local f = assert(fs.open(fname))
      print(f:read("*l"))
      f:close()
    end

**That** is impressive. We haven't really changed anything in our code.
Our Lua functions don't care where the files are. All filesystem
interaction go through MC's *Virtual File System* layer.

Note our use of @{fs.open} instead of Lua's builtin @{io.open}. The
latter uses the C library directly and therefore doesn't recognize MC's
_Virtual File System_. Therefore, as a rule of thumb, use @{fs.open}
instead of @{io.open}.

Our example has another interesting point. We read only one line of each
file. On economically-implemented filesystems this would fetch only one
block of the file (e.g., over a network) instead of the whole file.

## Handling errors

In regards to errors, our Lua functions follow a loose convention used
in the Lua world: IO functions that fail don't usually raise an
exception. Instead, such function returns a triad: a nil, an error
message, and an error code. If you want to raise an exception, wrap the
function call in @{assert} (as was done above).
