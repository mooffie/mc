--[[

GitHub-style "folder jumping"
-----------------------------

This module implements, for MC, what GitHub calls "folder jumping":

    https://github.com/blog/1877-folder-jumping

Explanation: If directory "a" contains only directory "b", and no other
files, you'll see "a/b" in the panel and pressing ENTER will take you
straight to "b" instead of going through "a".

If you want to chdir to "a", instead of to "a/b", then probably the
easiest way is to enable the Lynx movement keys (and use the right
arrow).

This feature is a great time-saver when navigating projects written in
languages whose "namespaces" translate to filesystem folders, like Java
or modern PHP.

This feature does not affect the behavior of MC (except for the ENTER
key). For example, <F5> (copy) will copy the "a" dir, not "a/b". In other
words, this feature only affects the way directories are *shown*, not the
way they're *stored* in the panel listing. Although you see "a/b" on
screen, MC still sees this as just "a". This is a very good thing:
otherwise things would turn ugly.

Installation
------------

    require('samples.fields.github-folder-jumping')

You can also customize it:

    local fj = require('samples.fields.github-folder-jumping')

    fj.nlink_optimization = true  -- Make it faster.
    fj.separator = ' ◠◡▷ '  -- Show a fancy separator instead of plain "/".

FAQ
---

- "Will it make navigation slower?"

- Not really. It's supposed to make it slower, because directories need to
be examined to see it they contain solitary sub-directories, but in
practice I haven't noticed slowness (and I'm using a slow machine!). If
you're conscientious about performance, turn on the 'nlink_optimization'
flag.

]]

local M = {}

------------------------------- Customizations -------------------------------

--
-- nlink optimization.
--
-- If 'true', only directories having 3 hard-links to them (as indicated
-- in stat's 'nlink' field) will be candidates for folder jumping.
--
-- This is 'false' by default because NTFS filesystems always have 1 links
-- for directories (at least on my system). Another scenario where this
-- "fails" is when the solitary directory is a symlink (in which case the
-- parent directory will have 2 links, not 3).
--
M.nlink_optimization = false

---
-- The separator to display. You can use fancy characters, like " ► ".
-- Tip: see http://stackoverflow.com/a/16509364/1560821 for ideas.
--
M.separator = '/'

--
-- Whether to turn off this feature in panelized panels.
--
-- This is 'true' by default because such panels may already contain items
-- like "dir1/dir2" and we don't want the user to be confused ("does `dir1`
-- contains just `dir2`, or is my panelized panel showing me `dir/dir2`?)
--
M.exclude_panelized = true

--
-- You can re-define this function to turn off this feature for
-- certain directories (that is, to "exclude" them).
--
-- The default implemention excludes directories residing on non-local
-- filesystems (e.g., SSH, archives, etc.), assuming they'd be slower
-- to process.
--
function M.is_excluded(pnl)
  return not pnl.vdir:is_local()
end

----------------------------------- Utils ------------------------------------

local function DBG(msg)
  devel.log('--' .. msg)
end

---------------------------------- The crux ----------------------------------

--
-- This is the function that calculates the "figure" of a directory.
-- "Figure" is how we call the way a directory with jumps is shown. E.g.,
-- the figure of "dir1" is "dir/dir2" (if it contains only "dir2").
--

local function figure(path, figure_so_far)

   local dirh = fs.opendir(path)

   local solitary_dir = nil

   if dirh then
     local fname = dirh:next()
     if fname then
       -- Note that we choose to use stat(), not lstat(), so that symlinks
       -- to dirs are considered as dirs. But the nlink=3 optimization won't
       -- work for this case.
       if fs.stat(path .. "/" .. fname, "type") == "directory" then
         solitary_dir = fname
       end
       if dirh:next() then
         -- There are more files.
         solitary_dir = nil
       end
     end
     dirh:close()
   end

   if solitary_dir then
      figure_so_far = figure_so_far .. "/" .. solitary_dir
      local figure_next = figure(path .. "/" .. solitary_dir, figure_so_far)
      if figure_next then
        return figure_next
      else
        return figure_so_far
      end
   end

end

--
-- Calculates the "figures" for the entire panel's directory. The 'stat'
-- buffers are already available to us.
--
local function figure_entire_panel(pnl)

  local slot = {}

  for fname, stat in pnl:files() do
    if fname ~= ".." and stat.type == "directory"
         and (not M.nlink_optimization or stat.nlink == 3)
    then
      slot[fname] = figure(pnl.dir .. "/" .. fname, fname)
    end
  end

  return slot

end

---------------------------------- Caching -----------------------------------

--
-- We store the figures in a cache (as it'd be inefficient to calculate them
-- anew whenever the panel paints a filename).
--
local cache = {}

--
-- Returns the "figure" of a file.
--
-- Returns nil or false if it doesn't have one (or if it's not a dir, or if
-- the panel is excluded).
--
local function get_cached_figure(pnl, fname)

  local slot = cache[pnl.dir]

  if not slot then
    DBG('gthb: calculating for entire dir ' .. pnl.dir)
    slot = (not M.is_excluded(pnl)) and figure_entire_panel(pnl) or {}
    cache[pnl.dir] = slot
  end

  return slot[fname]

end

ui.Panel.bind('<<load>>', function(pnl)

  -- There may be new files, or some sub-dirs are no longer solitary, so
  -- forget this dir's cache:
  cache[pnl.dir] = nil

  -- To conserve memory, we delete the entire cache from time to time (% probability).
  if math.random() < 0.20 then
    cache = {}
  end

end)

----------------------------- ENTER key binding ------------------------------

--
-- This table remembers which directories the '..' entry should go to. E.g.:
--
--   ups['/path/dir1/dir2'] = { dir = '/path', fname = 'dir1' }
--
--
local ups = {}

ui.Panel.bind_if_commandline_empty('enter', function(pnl)
  -- Note: When the panel is panelized, and if the user uses the
  -- 'samples.accessories.follow' module to follow files with ENTER,
  -- then we won't arrive at this code.
  local fname, stat = pnl:get_current()
  if stat.type == 'directory' then
    if fname == '..' then
      --
      -- Up.
      --
      if pnl.panelized then
        -- The '..' of a panelized panel is special: it's used to reload
        -- the current dir. So we pass it on to MC.
        return false
      end
      local prev = ups[pnl.dir]
      if prev then
        ups[pnl.dir] = nil
        pnl.dir = prev.dir
        pnl.current = prev.fname
        return
      end
    else
      --
      -- Down.
      --
      local old_dir = pnl.dir
      local dest = get_cached_figure(pnl, fname)
      if dest then
        if pnl:set_dir(dest) then
          ups[pnl.dir] = {
            dir = old_dir,
            fname = fname
          }
        else
          alert(T"Cannot change directory")
        end
        return
      end
    end
  end
  return false  -- Important! Let MC handle the rest.
end)

--------------------------------- Debugging ----------------------------------

function M.debug()
  ui.Panel.bind_if_commandline_empty('\\', function()
    devel.view {
      ups,
      cache,
      nlink_optimization = M.nlink_optimization,
    }
  end)
end

----------------------------------- Field ------------------------------------

--
-- To display the "figures" we re-refine the "Name" field.
--

local function render_fname(dir, fname, pnl)

  local figure = (not (M.exclude_panelized and pnl.panelized)) and get_cached_figure(pnl, fname)

  if figure then
    if M.separator ~= '/' then
      figure = figure:gsub('/', M.separator)
    end
    return figure
  else
    return fname
  end

end

ui.Panel.register_field {
  id = "name",
  title = N"&Name",
  sort_indicator = N"sort|n",
  default_width = 12,
  default_align = "left~",
  expands = true,
  render = function(fname, stat, width, info)
    return render_fname(info.dir, fname, info.panel)
  end,
  sort = "name"
}

------------------------------------------------------------------------------

return M
