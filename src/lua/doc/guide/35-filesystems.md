
# Filesystems

File operations in MC are done through a layer called *Virtual File
System*. This extra layer of indirection lets programmers plug in their
own custom filesystems.

Traditionally, MC has let you create custom filesystems using your
own external scripts. E.g., a shell script, a Perl script.

You can now write your filesystems in Lua. Some of the advantages are:

- __Portability__
  --<small>_You're not dependent on external programs that vary between systems._</small>
- __Ease of installation__
  --<small>_Just drop a single Lua file in your Lua directory._</small>
- __Perfromance__
  --<small>_You can keep state in memory._</small>
- __Functionality__
  --<small>_You can implement all conceivable filesystem operations._</small>

## Creating a filesystem

You create a filesystem by describing, in a table, how its various file
operations are performed, and then registering this information:

    local myfs = {
      prefix = "myfs",
      ...
      open = function(...) ... end,
      stat = function(...) ... end,
      rename = function(...) ... end,
      delete = function(...) ... end,
      ...
    }

    fs.register_filesystem(myfs)

You can then access this filesystem anywhere in MC by embedding "myfs://" in pathnames.

Let's look at it in detail.

Info-short: This document uses the terms "functions", "operations" and
"operators" interchangeably.

## In detail

There are more than two dozen file operations (reading a file, closing,
seeking, renaming, deleting, etc.), and for each of them you can provide
an implementation.

Thankfully, however, for a filesystem to function all you *have* to
implement is 2 or 3 operations. When you register a filesystem it gets
analyzed and if it's missing some crucial operation you'll be informed
of this with a friendly error message. This way you don't need to
memorize much.

Let's start with a minimal working filesystem. Put the following in a
file in your user's Lua folder and restart MC:

    local myfs = {

      prefix = "myfs",

      readdir = function (_, dir)
        if dir == "" then
          return {"one.txt","two.txt","three.txt"}
        end
      end

    }

    fs.register_filesystem(myfs)

We've implemented the @{luafs.readdir|readdir} operation, which, given
a directory name, returns all the files in it. We can test our
filesystem by issuing `cd myfs://` inside MC or by doing
`devel.view(assert(fs.dir("myfs://")))` in Lua.

Tip-short: The @{luafs.prefix|prefix} field makes the system associate
paths with our filesystem.

Note the first parameter to our "readdir" function, which we ignore
(underscore is a common Lua idiom). It stands for the *session*, but we
won't use it in our filesystem; we'll learn about *sessions* later. All
operators get this first parameter.

We wrote our code in a JavaScript style. It's fine, but let's switch to
Lua style:

    local MyFS = {
      prefix = "myfs",
    }

    function MyFS:readdir(dir)
      if dir == "" then
        return {"one.txt","two.txt","three.txt"}
      end
    end

    fs.register_filesystem(MyFS)

The files `readdir` reports are by default regular files with zero
size. If you want to change this, implement @{luafs.stat|stat}.

Now, we want to provide access to our files.

One way to do this is to implement the operators @{luafs.open|open},
@{luafs.read|read}, @{luafs.write|write}, @{luafs.seek|seek} and
@{luafs.close|close}.

The other way is to implement just one operator, @{luafs.file|file},
instead. This operator is similar to the @{luafs.open|open} operation:
it gets the pathname to the file to be opened, the opening mode (read,
write, etc.), and some other potentially useful information. The
operator should return either a file object (@{fs.File} or @{io.open}),
or a string which is the file's content.

lets start by returning a string:

    function MyFS:file(pathname, mode)
      if pathname == "one.txt" then
        return "This is the contents of one.txt"
      end
    end

This could be convenient for filesystems containing short statistics
messages. BTW, it's alright for zero size files (as reported by stat()) to
contain data.

Let's return a file object instead:

    function MyFS:file(pathname, mode)
      if mode == "r" then
        if pathname == "one.txt" then
          return fs.open("/etc/fstab", mode)
        end
      end
    end

here we make our "one.txt" file mirror "/etc/fstab". This is
nonsensical, of course. Let's now do something useful instead. Let's
have "one.txt" be the output of some OS command. We might be tempted to
do:

    function MyFS:file(pathname, mode)
      if mode == "r" then
        if pathname == "one.txt" then
          return io.popen("df -H")
        end
      end
    end

Which would work, but MC's editor wants to seek() in the file when it
opens it (for no good reason) and pipes don't respond to seeking. A
workaround is to write the data to a temporary file and return it
instead:

    function MyFS:file(pathname, mode)
      if mode == "r" then
        if pathname == "one.txt" then
          local f, tmpname = fs.temporary_file()
          os.execute("df -H > " .. tmpname)
          fs.unlink(tmpname)
          return f
        end
      end
    end

## Sessions

A filesystem often needs to manage some _state_.

Examples:

- A filesystem showing an archive's contents may want to cache an index
of the files within.

- A filesystem showing a database's contents may want to remember the
username/password.

- A network filesystem needs to keep an open socket.

We call this state a **session**. A session is an object (a Lua table)
with which you can do **whatever** you want.

A session, in object-oriented parlance, is an **instance** of a
filesystem class. It's the first argument to all our operator functions.
It's the `self` Lua argument implicit in all our operators.

## Archives

Let's use the session concept to implement an "archive" filesystem.

First, let's discuss what happens when our filesystem is accessed for
the first time. Let's imagine that the following pathname is accessed:

    /path/outside/myfs://path/inside

The system first asks each of our MyFS sessions if this pathname is
under its control. If the answer is negative, it builds a new session
for us. @{luafs.is_same_session|By default}, '/path/outside' is used to
identify sessions. In other words, by default, the following two paths
belong to the same session:

    /path/to/file.pkg/myfs://one.txt
    /path/to/file.pkg/myfs://two.txt

The following two paths, however, belong to two different sessions:

    /path/to/file.pkg/myfs://one.txt
    /path/to/file2.pkg/myfs://one.txt

When a session is created, your filesystem is asked to initialize it.
This is done using the @{luafs.open_session|open_session} operator.

Let's have an example. We'll make a filesystem for showing the sections in
a [Markdown](http://daringfireball.net/projects/markdown/) file. A
section is announced by a line beginning with a "#" character. Here's a
sample Markdown file:

    @plain
    # Sample Markdown file

    ## Section 1

    Here's a section.

    ## Section 2

    Here's another section.
    Nothing more to see here.

First, we need code to split the text above into sections:

````lua
--
-- Splits markdown text into sections.
--
-- Returns a table in this form:
--
--   {
--      ["001. Intro"] = "......",
--      ["002. Overview of filesystems"] = "......",
--      ["003. Summary"] = "....."
--   }
--
local function split_sections(text)

  local section_re = [[
    (
      ^ \#+ \s* ([^\n]*)   # Header
      .*?                  # Body
      (?=^\#)              # Stop at the next header.
    )
  ]]

  local sections = {}
  local counter = 1

  for raw, header in (text .. "\n#"):p_gmatch {section_re, "smx"} do
    local numbered_header = ("%03d. %s"):format(counter, header)
    sections[numbered_header] = raw
    counter = counter + 1
  end

  return sections

end
````

Next, we write our filesystem and register it:

````lua
local MarkdownFS = { prefix = "markdown" }

function MarkdownFS:open_session()

  if fs.stat(self.parent_path, "type") ~= "regular" then
    abort(T"File %s isn't a regular file.":format(self.parent_path.str))
  end

  local text = assert( fs.read(self.parent_path) )

  -- Since MarkDown files are relatively small, we keep all the sections
  -- in memory. For filesystems representing potentially big archives
  -- we'd store in memory just an index to the locations on disk.
  self.sections = split_sections(text)

end

local append = table.insert

-- Reports all the "files" (sections) in our MarkDown file.
function MarkdownFS:readdir(path)
  local names = {}
  for name, _ in pairs(self.sections) do
    append(names, name)
  end
  return names
end

-- Opens a "file".
function MarkdownFS:file(path)
  return self.sections[path]
end

-- Convenience: makes pressing ENTER in a panel over MarkDown files
-- automatically 'cd' to them.
MarkdownFS.glob = "*.{md,mkd,mdown}"

fs.register_filesystem(MarkdownFS)
````

Now, to test our filesystem we need to locate some markdown file. If you don't have one, create one. Then, in MC, type:

    cd /path/to/file.md/markdown://

...and you'll see the "contents" of the file.

[info]

As a convenience, you can tell MC to automatically "cd" to an archive,
when the user presses ENTER over it, by using any of the properties
@{luafs.glob|glob}, @{luafs.iglob|iglob}, @{luafs.regex|regex} and
@{luafs.iregex|iregex}:

    local MarkdownFS = {
      prefix = "markdown",
      glob = "*.md",
    }

[/info]

Finally, note that if you do:

    cd markdown://

MC sees this as relative path and adds the current directory in
front. So it translates to: `/current/directory/markdown://`.

## Examining the open sessions

Under MC's "Command" menu you'll find the command "Active VFS list" (C-x a).
It lists Lua filesystems as well. Lua filesystems behave just like
non-Lua ones and they are freed automatically after X minutes when not
in use.

When a Lua filesystem is freed, the @{luafs.close_session|close_session}
operation is called. We haven't used it in our Markdown example, but we
would use it, for example, if we needed to delete temporary files or
close a socket.

## Non-archive sessions

Let's imagine a filesystem which shows MySQL tables. We'd invoke it using:

    cd mysql://

We've said earlier that this is a relative path and that MC prepends the
current directory to it. This means that MC actually sees
`/current/directory/mysql://`. There's no problem in this per se: our
filesystem will work as expected. However, if we do `cd mysql://` later,
from a different directory, MC won't re-use the existing open session (if
it's still open). This results in two sessions being open.

To solve this, we have to tell MC, when it interrogates us about any
path, that it belongs to our session. We do this using the
@{luafs.is_same_session|is_same_session} operation.

    function MysqlFS:is_same_session()
      return true
    end

    function MysqlFS:get_name()
      return "mysql://"
    end

