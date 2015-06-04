
# Fields

Fields are the columns shown in the file manager’s @{ui.Panel|panels}.
They show the attributes of your files.

You're already familiar with built-in fields like **Name**, **Size**,
**Modify time**, **Inode**, etc. You can easily create your own fields.
Fields you create via Lua behave exactly like built-in fields.

The user can choose which fields to show in a panel and which field to
sort by.

## Creating fields

You create a field by describing it, in a table, and
@{ui.Panel.register_field|registering} it:

    local my_field = {
      id = "hello",
      title = N"Our first field",
      render = function()
        return T"Hello World!"
      end,
    }

    ui.Panel.register_field(my_field)


Then you tell MC to use this field. For fields that show information,
like the field we've just created, you do this using the "Listing mode"
dialog:

<pre class="screenshot">
┌─────────────── Listing mode ───────────────┐
│ ( ) Full file list                         │
│ ( ) Brief file list                        │
│ ( ) Long file list                         │
│ (*) User defined:                          │
│ half type name | <b>hello</b> | size | perm   [^] │
├────────────────────────────────────────────┤
│ [x] User mini status                       │
│ half type name | size | perm           [^] │
├────────────────────────────────────────────┤
│            [< OK >] [ Cancel ]             │
└────────────────────────────────────────────┘
</pre>

Note the "hello", the **id** of our field, we added to the format string. Our
field will then be shown in the panel:

<pre class="screenshot">
  Left     File     Command     Options     Right
┌<─ ~/symfony/src/Symfony/Component/Stopwatch ───.[^]>┐
│'n          Name           │Our fi│ Size  │Permission│
│/..                        │Hello │UP--DIR│drwxrwxr-x│
│/Tests                     │Hello │   4096│drwxrwxr-x│
│ .gitattributes            │Hello │     52│-rw-rw-r--│
│ .gitignore                │Hello │      8│-rw-rw-r--│
│ LICENSE                   │Hello │   1065│-rw-rw-r--│
│ README.md                 │Hello │    255│-rw-rw-r--│
│ Stopwatch.php             │Hello │   6579│-rw-rw-r--│
│ StopwatchEvent.php        │Hello │   4795│-rw-rw-r--│
│ StopwatchPeriod.php       │Hello │   1639│-rw-rw-r--│
│ composer.json             │Hello │    743│-rw-rw-r--│
│ phpunit.xml.dist          │Hello │    824│-rw-rw-r--│
│                           │      │       │          │
│                           │      │       │          │
├─────────────────────────────────────────────────────┤
│ README.md                        │    255│-rw-rw-r--│
└───────────────────────────────────── 708M/24G (2%) ─┘
 1Help  2Menu  3View  4Edit  5Copy  6Re~ov 7Mkdir
</pre>

(Our field wasn't allocated enough room to show all the 12 characters
of the string "Hello World!". One way to fix this is with
@{fields.default_width|default_width}.)

## Rendering a field

The function stored at the "@{fields.render|render}" key is the one responsible for
rendering a field. The string it returns is what the user sees in
the panel.

The render function we defined previously is quit useless. This doesn't
have to be so. The rendering function receives a few useful arguments:
the file's name (it's base name only), the file's @{fs.StatBuf|stat}, the field's width, and
an "info" basket containing the panel and the panel's direcrory:

    -- A field showing an uppercased version of a file's name.
    ui.Panel.register_field {
      id = "upname",
      title = N"Uppercased name",
      render = function(filename, stat, width, info)
        return filename:upper()
      end,

      -- Non-critical definitions:
      default_align = "left~",
      default_width = 20,
      expand = true,
    }

(The next example shows a field that uses the @{fs.StatBuf|stat} argument.)

We've also shown in this example a few render-related keys
(@{fields.default_align|default_align},
@{fields.default_width|default_width}, @{fields.expands|expands}).

## Sortable fields

The *optional* function stored at the "@{fields.sort|sort}" key is the one
responsible for sorting a field. This function should return a number
less than, equal to, or greater than zero, depending on which of the two
files given to it is greater.

Once you implement this function your field will appear on MC's sort
dialog and you'll be able to activate it.

Let's create, for example, a "file age" field, which prints a file's
modification date in a very @{utils.text.format_interval_tiny|compact form}
("1d", "2M", etc.).

    local format_interval_tiny = require("utils.text").format_interval_tiny

    ui.Panel.register_field {
      id = "age",
      title = N"File's a&ge",

      --
      -- Rendering definitions.
      --
      render = function(filename, stat)
        return format_interval_tiny(os.time() - stat.mtime)
      end,
      default_width = 5,
      default_align = "right~",

      --
      -- Sorting definitions.
      --
      sort = function(filename1, stat1, filename2, stat2)
        return stat1.mtime - stat2.mtime
      end,
      sort_indicator = N"sort|age",
    }

Instead of writing your own sort function you may re-use the sort of a
built-in field. You do this by assigning to the **sort** key the name
(string) of an existing built-in field:


    ui.Panel.register_field {
      id = "age",
      title = N"File's a&ge",

      -- ... everything else is as before...

      sort = "mtime"
    }


## Overriding built-in fields

You can give your fields the same **id** as that of built-in fields.
This way you can tweak (or altogether replace) the behavior of these fields.

For example, MC doesn't print commas in files' sizes, which sometimes
makes it awkward to read such numbers. Here we re-define the `size`
field to fix this usability problem (with the help of
@{utils.text.format_size|format_size}:

    local format_size = require("utils.text").format_size

    -- Print file sizes with commas.
    ui.Panel.register_field {
      id = "size",
      title = N"&Size",
      sort_indicator = N"sort|s",
      default_width = 8,
      default_align = "right",
      render = function(filename, stat, width, info)
        if filename == ".." then
          return T"UP--DIR"
        else
          return format_size(stat.size, width, true)  -- the crux!
        end
      end,
      sort = "size"
    }


As another example, here's a re-definition of the `name` field which makes
it sortable the *version* way (so that "file2.gif" comes before "file10.gif"):

    ui.Panel.register_field {
      id = "name",
      title = N"&Name",
      sort_indicator = N"sort|n",
      default_width = 12,
      default_align = "left~",
      expands = true,
      render = function(filename)
        return filename
      end,

      -- The following is the crux of this example. Everything
      -- else mimics the built-in 'name' field.
      sort = "version"
    }


(The @{git:samples/fields/bidi.lua|samples.fields.bidi} module overrides
the `name` field in a similar manner to support BiDi languages.)

## Efficiency

Sometimes calculating a field's contents can be costly. For example,
some fields may require launching an external program:

- A "duration" field showing a video's length entails invoking mplayer.
- A "gitcomment" field showing a file's last commit message involves invoking git.

Clearly, if we had to launch the external program each time our `render`
function is called the result would be extremely slow.

To solve this problem we can launch the external program to process an
entire directory. We'd store the result in some cache. Then our 'render'
function would look up in this cache.

As an example, let's re-define the `name` field to display itself in
uppercase. We'll do the uppercasing with the help of the `tr` shell
tool. This is, of course, a silly way to do it, but it demonstrates our
topic well:

````
local cache = {}

--
-- Runs external process to upcase a directory index.
--
local function run_upcase(dir)
  local cmd1 = ("ls -a %q"):format(dir)
  local cmd2 = ("ls -a %q | tr a-z A-Z"):format(dir)
  devel.log('Running ' .. cmd2)
  local f1 = io.popen(cmd1)
  local f2 = io.popen(cmd2)
  local result = {}

  for source in f1:lines() do
    result[source] = f2:read()
  end

  f1:close()
  f2:close()
  return result
end

--
-- Upcase an entire directory.
--
local function upcase_dir(dir)
  if not cache[dir] then
    -- We can't run op-sys commands on non-local filesystem (e.g., inside archives).
    if fs.realpath(dir) then
      cache[dir] = run_upcase(dir)
    else
      cache[dir] = {}
    end
  end
  return cache[dir]
end

--
-- Upcase a single file name.
--
local function upcase_name(dir, fname)
  local db = upcase_dir(dir)
  -- The "or" branch is for non-local filesystems.
  return db[fname] or fname
end

ui.Panel.register_field {
  id = "name",
  title = N"&Name (uppercased)",
  sort_indicator = N"sort|n",
  default_width = 12,
  default_align = "left~",
  expands = true,
  render = function(fname, stat, width, info)
    return upcase_name(info.dir, fname)
  end,
  sort = "name"
}

-- This code has a caching bug! See discussion.
````

<a name="clearing-cache"></a>

**Clearing the cache**

The code above seems to function perfectly, till we add or rename files
in a directory. Then we notice that the new names don't become uppercased.

This is because our cache still reflects the old directory index. We
need a way to clear our cache. There are several ways to do it.

The most straight-forward way is to do this when a panel's
@{ui.Panel:load|load event} is triggered:

    ui.Panel.bind('<<load>>', function(pnl)
      cache[pnl.dir] = nil
    end)

For very costly fields --those which entail running "heavy" programs
like mplayer-- we'd assume the user won't mind seeing stale data till she
explicitly asks to refresh it via "reload" (`C-r`). For such fields we'd use
the @{ui.Panel:flush|flush event} instead:

    ui.Panel.bind('<<flush>>', function(pnl)
      cache[pnl.dir] = nil
      -- Or we can do 'cache = {}' to clear the entire cache.
    end)

Some other ways to clear the cache is making it a weak table, or using
timers.

**Enabling fields on-demand**

Another --or a complementary-- approach to handling costly fields is to
let the user enable/disable them with a hotkey.

To do that, write your field module thus:

````
local M = {
  enabled = true,
}

-- ...
-- ... previous code snippet out ...
-- ...

ui.Panel.register_field {
  ...
  render = function(fname, stat, width, info)
    return M.enabled and upcase_name(info.dir, fname) or fname
  end,
  ...
}

return M

````

and in your module's documentation provide the following code snippet for activation:

    local upcasef = require('myfields.upcase')
    upcasef.enabled = false

    ui.Panel.bind('C-f g e', function(pnl)
      upcasef.enabled = true
      pnl:reload()
    end)

    ui.Panel.bind('C-f g d', function(pnl)
      upcasef.enabled = false
      pnl:reload()
    end)

(The sequence 'C-f u e' stands for "[f]ields, [u]pcase, [e]nable". Of
course, you may use any other sequence, but perhaps it's wiser for the
community to settle on this convention.)

**An alternative**

An alternative to this scheme of enabling/disabling fields, at least from
the point of view of the user, is to use the
@{git:snapshots|snapshots} module. The idea is to store, in a
snapshot, your custom format(s) only (a custom format which would contain
the fields in question). You may also setup another snapshot without the
fields. You can then very easily toggle the fields.
