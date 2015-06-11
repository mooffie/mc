--[[

Contents
========

This is a very simple, and inefficient, glob() implementation. We can't
use the system's glob() as it doesn't support the VFS.

(GNU libc's glob() actually does let us plug in our own
readdir()/stat()/etc handlers, so this could solve the problem. It
remains to be seen if it supports "**" and reporting files as soon as
they're found.)

The implementation
==================

Let's consider:

  glob('/path/to/what{ever/is,nice}/dir/*.txt')

The first thing we do is break the pattern into two:
the longest prefix that has no wildcards (START), and
everything which follows (REST):

  { START = '/path/to/', REST = 'what{ever/is,nice}/dir/*.txt' }

Also, the pattern is converted to a regex:

  REGEX = '^/path/to/what(ever/is|nice)/dir/([^/]*)\\.txt$'

Next, the filesystem is traversed recursively starting at START. The full
pathname of every file found is built and matched against REGEX. If it
matches (and possibly other conditions are met), it's included in the
result.

REST is used to estimate the recursion depth. Usually it's the number of
slashes. When doing glob('/etc/*'), REST is '*' and so the depth is
estimated to be 1 and no further directories are traversed.

Drawbacks
=========

- glob("/proc/[0-9]*/exe") will traverse all the directories immediately in /proc.
- glob("/{,s}bin/**/d*") will traverse the entire filesystem.

]]
--- @module fs

local glob_compile = require('utils.glob').compile
local tty_is_utf8 = require('tty').is_utf8()

local function compile_pat(gpat, opts)
  return glob_compile(gpat,
    (opts.nocase and "i" or "") ..
    (opts.utf8 == nil  -- logic explained in glob().
      and (tty_is_utf8 and "u" or "")
      or  (opts.utf8   and "u" or ""))
  )
end

--------------------------------- do_glob() ----------------------------------

local function join(path, base)
  if not path then
    return base
  end
  return path .. (path:find "/$" and "" or "/") .. base
end

local function do_glob(dir, re, opts, level)

   local dirh, error_message = fs.opendir(dir or ".")

   if not dirh then
     if opts.fail then
       error(error_message)
     else
       return  -- fail silently.
     end
   end

   for fname in dirh.next, dirh do

     local full = join(dir, fname)
     local does_match = regex.match(full, re)
     local stat

     if opts.recurse or (does_match and (opts.type or opts.mark_dirs or opts.conditions)) or opts.stat then
       -- We do stat() only if needed.
 
       -- Note: It happened to me while traversing /proc that some files "disappear"
       -- and stat() therefore fails ("No such file or directory"), so the "or {}" is
       -- to suppress this issue.
       stat = fs.lstat(full) or {}
     end
 
     if does_match and opts.type then
       does_match = (stat.type == opts.type)
     end

     if does_match and opts.conditions then
       for _, cond in ipairs(opts.conditions) do
         if not cond(full, stat, fname) then
           does_match = false
           break
         end
       end
     end

     if does_match and opts.mark_dirs then
       if stat.type == "directory" then
         full = full .. "/"
       end
     end

     if does_match then
       opts.handler(full, stat)
     end

     if opts.recurse and stat.type == "directory" then
       if level < opts._max_depth then
         do_glob(full, re, opts, level + 1)
       end
     end

   end
end

------------------------------- glob_generic() -------------------------------

local WILDCARD = '[*?{[]'
local NON_WILDCARD = '[^*?{[]'

local function has_wildcards(s)
  return s:find(WILDCARD)
end

--
-- Breaks 'anything/before/the.*/and/beyond' into ('anything/before/', 'the.*/and/beyond')
--
local function breakp(gpat)
  local base, rest = gpat:match("^(" .. NON_WILDCARD .. "*/)(.*)")
  if base then
    return base, rest
  else
    return nil, gpat
  end
end

local function test_breakp()
  local ensure = devel.ensure
  ensure.equal( {breakp("/one/*.txt")}, { "/one/", "*.txt"}, "breakp #1" )
  ensure.equal( {breakp("*.txt")}, { nil, "*.txt"}, "breakp #2" )
  ensure.equal( {breakp("one")}, { nil, "one"}, "breakp #3" )
  ensure.equal( {breakp("a/b/c")}, { "a/b/", "c"}, "breakp #4" )
  ensure.equal( {breakp("/a")}, { "/", "a"}, "breakp #5" )

  -- breakp() will never be called with a trailing "/" so the following aren't needed.
  --ensure.equal( {breakp("a/")}, { "a/", ""}, "#6" )
  --ensure.equal( {breakp("a/b/c/")}, { "a/b/c/", ""}, "#7" )
end

--
-- Given a pattern, like "one/ab?/cd/*", tries to calculate the maximal depth
-- we need to traverse to find all the matching files.
--
-- This function does *not* need to give an exact result. It may err in
-- favor of a greater depth but not in favor of lower depth.
--
local function estimate_max_depth(s)
  if s:find "%*%*" then
    return math.huge  -- Infinite depth (e.g., "**/file.c").
  end
  return s:gsub("[^/]", ""):len() + 1
end

local function test_depth()
  local ensure = devel.ensure
  ensure.equal(estimate_max_depth("one"), 1, "max_depth #1")
  ensure.equal(estimate_max_depth("one/two"), 2, "max_depth #2")
  ensure.equal(estimate_max_depth("**/two"), math.huge, "max_depth #3")
  ensure.equal(estimate_max_depth("one/{two/three,four/five}/yup"), 5, "max_depth #4") -- the real depth is 4, but it's ok to err upward.
end


local function glob_generic(gpat, opts)

  assert(opts)
  assert(opts.handler)

  -- Special case:
  --
  -- This handles the glob('/') and glob('mysql://') case.
  --
  -- It also early-exists the glob('/existing/file') and glob('/existing/dir/')
  -- cases (instead of matching all the files in '/existing/' against 'file' or
  -- 'dir'), but this is just a nice non-critical by-product.
  --
  -- The has_wildcards() is needed because people are going to be lazy when
  -- writing LuaFS filesystems and omit a decent stat() function and so 'mysql://*'
  -- will be reported as an actual file. We want to avoid that here.
  if not has_wildcards(gpat) and fs.lstat(gpat) then
    opts.handler(gpat, fs.lstat(gpat))
    return
  end

  -- If the pattern ends in "/", we're to return only directories.
  if gpat:find "/$" then
    gpat = gpat:gsub('/+$', '')
    opts.type = "directory"
    opts.mark_dirs = true
  end

  local start, rest = breakp(gpat)

  opts._max_depth = estimate_max_depth(rest)
  opts.recurse = (opts._max_depth > 1)  -- Are we to recurse sub-directories?

  local re = compile_pat(gpat, opts)
  do_glob(start, re, opts, 1)
end

------------------------------------------------------------------------------

---
-- Globbing.
--
-- Iterates over all files matching a shell pattern. Returns the file paths.
--
--    for file in glob('/home/mooffie/Documents/**/*.txt') do
--      print(file)
--    end
--
-- The files aren't sorted: the block is executed as each file is found.
--
-- **Options**
--
-- The optional **opts** table holds various customization options and flags.
--
-- - opts.nocase - If *true*, ignores case when matching filenames. "*.c" would match both "file.c" and "file.C".
-- - opts.utf8 -- If *true*, filenames are assumed to be UTF-8 encoded
--   ("?" matches a character, not byte, and *ops.nocase* works). If *false*,
--   this handling is turned off. If missing (*nil*), decision is based on
--   @{tty.is_utf8} (as MC @{2743|itself does}).
-- - opts.fail - If *true*, an exception is raised in case of error (e.g., directory with no read permission, etc.); otherwise, errors are silently ignored.
-- - opts.conditions - a list of functions to filter the results by. Each function ("predicate") gets
--   the following arguments: the full path, a @{fs.StatBuf}, and the basename. It should
--   return _true_ if the file is to be included in the results. A file has to satisfy all the conditions.
-- - opts.stat - If *true*, returns a @{fs.StatBuf} in addition to the file path.
-- - opts.type - Limits the results to files of a certain type.
--
-- Tip: Both `glob("\*", {type="directory"})` and `glob("\*/")` are ways to limit results to
-- directories only, but the latter appends a slash to each name.
--
-- **Patterns**
--
-- The usual shell patterns are recognized. Curly brackets denote alternatives. "`\*\*`" descends into subfolders.
-- In contrast to the shell, "`\*`" **does** match dot at start of
-- filename (if you want to eliminate such files, use *ops.conditions*, as
-- demonstrated below).
--
--    -- Get rid of files beginning with dot.
--    local function nodot(_,_,base)
--      return not base:find '^%.'
--    end
--
--    -- Note the 'nocase': we want "img.GIF" to match too.
--    for f in fs.glob("*.{gif,jp{e,}g}", {conditions={nodot}, nocase=true}) do
--      ...
--    end
--
-- Note: It may [not be safe](http://stackoverflow.com/questions/1676522/) to
-- delete files while traversing with `glob` (as it's essentially a @{readdir(3)}
-- loop). Use `tglob` instead.
--
-- See also @{tglob}.
--
-- @function glob
-- @args (pattern[, opts])

local function glob(gpat, opts)
  opts = opts or {}
  opts.handler = function(full, stat)
    coroutine.yield(full, stat)
  end
  return coroutine.wrap(function() glob_generic(gpat, opts) end)
end

---
-- Globbing, into a table.
--
-- Like @{glob}, but it isn't an iterator: the matching files are returned as a table.
--
-- The table returned is sorted.
--
--    local files = tglob('/home/mooffie/*.txt')
--
-- See @{glob} for the description of the arguments. In addition to the
-- options mentioned there, `tglob()` supports **nosort**, which disables the sorting
-- of the files.
--
-- @function tglob
-- @args (pattern[, opts])

local function tglob(gpat, opts)
  local list = {}
  opts = opts or {}
  opts.handler = function(full, stat)
    list[#list + 1] = full
  end
  glob_generic(gpat, opts)
  if not opts.nosort then
    table.sort(list)
  end
  return list
end

------------------------------------------------------------------------------

---
-- Matches a file against shell pattern.
--
-- Returns **true** if a filename matches a shell pattern. The file does not
-- need to exist.
--
--    if fnmatch("*.{gif,jp{e,}g}", filename) do
--      alert("It's an image!")
--    end
--
-- The optional **opts** argument is described in @{glob} (only *nocase* and
-- *utf8* are relevant).
--
-- @function fnmatch
-- @args (pattern, filename[, opts])

local function fnmatch(gpat, filename, opts)
  return regex.find(filename, compile_pat(gpat, opts or {})) ~= nil
end

------------------------------------------------------------------------------

return {
  glob = glob,
  tglob = tglob,
  fnmatch = fnmatch,
  internal_tests = function()
    test_breakp()
    test_depth()
  end
}
