--[[

Git utilities.

]]

-------------------------- utils ---------------------------

local function zlines(s)
  return s:gmatch("([^%z]+)%z")
end

local function open_command(dir, template, ...)
  local command = ("cd %q && " .. template):format(dir, ...)
  devel.log("Executing: " .. command)
  return io.popen(command)
end

local function try_command(dir, template, ...)
  local command = ("cd %q && " .. template):format(dir, ...)
  return require("samples.libs.os").try_program(command)
end

local function read_command(...)
  local f = open_command(...)
  local s = f:read('*a')
  f:close()
  return s
end

---------------- wrappers for git commands -----------------

local function _ls_tree(dir)
  local s = read_command(dir, "git ls-tree -z HEAD")
  for ln in zlines(s) do
    coroutine.yield(ln:match('^%S+%s(%S+)%s(%S+)%s(.*)'))  -- object-type, hash, file-name
  end
end

-- iterator
local function ls_tree(dir)
  return coroutine.wrap(function()
    _ls_tree(dir)
  end)
end

local function _status(dir, extra_args)
  local s = read_command(dir, "git status %s -z -- .", extra_args or "")
  local skip_line = false

  for ln in zlines(s) do
    if not skip_line then
      local code  = ln:sub(1,2)
      local fname = ln:sub(4)
      coroutine.yield(fname, code)
      if code:sub(1,1) == "R" then
        -- next line is the original name, which we aren't interested in.
        skip_line = true
      end
    else
      skip_line = false
    end
  end
end

-- iterator
local function status(dir, extra_args)
  return coroutine.wrap(function()
    _status(dir, extra_args)
  end)
end

------------------------------------------------------------------------------
-- Returns an "overview" of a folder. Similar to the one you see on Github.
--
-- Idea taken from this Perl script: https://github.com/thomasf/dotfiles-thomasf-base/blob/master/.bin/git-ls-dir
--
local function dir_overview(dir, extra_args)

  local unknowns = {}
  local unknowns_count = 0

  for kind, hash, fname in ls_tree(dir) do
    if kind == "blob" then   -- we exclude "tree"
      unknowns[hash] = { fname = fname }
      unknowns_count = unknowns_count + 1
    end
  end

  if unknowns_count == 0 then
    -- No tracked files here. No point in examining the log.
    devel.log("git.dir_overview(): no tracked files here.")
    return {}
  end

  local attributed = {}

  -- statistics:
  local commits_seen = 0
  local was_efficient = false

  -- (The "-- .", which is missing from the original code, cuts back on the
  -- commits we need to inspect. Is doesn't seem to ruin anything.)
  local f = open_command(dir, "git log -m --raw --no-abbrev %s --pretty=format:'%s' HEAD -- .", extra_args or "", "%H~%an~%at~%B")

  local commit, author, date, message

  for ln in f:lines() do
    local commit_meta = { ln:match('^(%x+)~([^~]*)~([^~]+)~(.+)') }
    if #commit_meta ~= 0 then
      commit, author, date, message = table.unpack(commit_meta)
      commits_seen = commits_seen + 1
    else
      local hash, fname = ln:match('^:%d+%s%d+%s%x+%s(%x+)%s[A-Z]%s(.*)')
      if hash then
        if unknowns[hash] then
          attributed[unknowns[hash].fname] = {
            commit = commit,
            author = author,
            date = date,
            message = message,
            fname = unknowns[hash].fname,
          }
          unknowns[hash] = nil
          unknowns_count = unknowns_count - 1
          if unknowns_count == 0 then
            was_efficient = true
            break
          end
        end
      end
    end
  end

  -- We ought to never see "INEFFICIENT" in the log.
  devel.log("git.dir_overview(): commits seen: " .. commits_seen .. ". " .. (was_efficient and "efficient." or "INEFFICIENT."))

  f:close()

  return attributed
end

------------------------------------------------------------------------------
-- Determines if some directory is managed by git.
--
-- If so, returns a 'true' value, which is actually a pair:
-- { the path within the repository, the repository's top-directory }
--

local dirname, basename = import_from("utils.path", { "dirname", "basename" })

local function under_git_control(dir, original)

  if not original then
    -- In case the dir is a symbolic link to somewhere inside a git
    -- repository, we must work on the real path to see that we're
    -- under git.
    dir = fs.realpath(dir)
    if not dir then
      -- Either the path doesn't exist, or it's on non-local filesystem (we
      -- don't support non-local FSs: we can't run commands there).
      return false
    end
    return under_git_control(dir, dir)
  end

  if dir == "/" then
    return false
  end

  if dir:find("/%.git$") then
    -- We're inside the git object store.
    return false
  end

  if fs.stat(dir .. "/.git", "type") == "directory" then
    -- Yes, it's a git repository!
    return original:sub(dir:len() + 2)   -- "+2" to remove the leading slash;
                   :gsub('/+$', ''),     -- ...and also remove the possible trailing slash(es).
           dir
  end

  if dir == "." then
    -- Prevent infinite recursion.
    return false
  end

  return under_git_control(dirname(dir), original)
end

------------------------------------------------------------------------------
-- Summarizes 'get status' of a directory.

local function status_summary(dir, extra_args)

  local prefix = under_git_control(dir)
  local fname_starts_at = (prefix == "") and 1 or (prefix:len() + 2) -- "+2" to get rid of the slash.

  local result = {}

  for fname, code in status(dir, extra_args) do

    fname = fname:sub(fname_starts_at)

    if fname:find('/') then
      -- Handle directories.
      --
      -- We report directories either as "??" (if they're untracked),
      -- or as "**" if there are issues with the files within (e.g.,
      -- modified, new or untracked files).
      local dir = fname:match('[^/]*')

      if not result[dir] then
        local is_sub_file = (fname ~= dir .. "/")

        if is_sub_file and code == "!!" then
          -- An ignored file isn't a good enough reason to flag the
          -- parent directory, so we do nothing.
        else
          result[dir] = (not is_sub_file) and code or "**"
        end
      end

    else
      result[fname] = code
    end
  end

  return result
end

------------------------------------------------------------------------------

return {

  -- preliminary.
  under_git_control = under_git_control,
  try_command = try_command,
  is_installed = function()
    return require('samples.libs.os').try_program('git --version')
  end,

  -- low level.
  status = status,
  ls_tree = ls_tree,

  -- higher level.
  status_summary = status_summary,
  dir_overview = dir_overview,

  -- queries.

  query__branch_name = function(dir)
    -- http://stackoverflow.com/questions/6245570/how-to-get-current-branch-name-in-git
    -- (the :match() trims the trailing \n.)
    return string.match(read_command(dir, "git rev-parse --abbrev-ref HEAD"), "[^\n]*")

    -- The post at http://stackoverflow.com/a/15111764/1560821 suggests
    --   git name-rev --name-only HEAD
    -- which shows tags.
  end,

  -- Return true if there are changes to the working tree: either staged changes or non-staged changes.
  query__is_dirty = function(dir)
    -- http://stackoverflow.com/questions/2657935/checking-for-a-dirty-index-or-untracked-files-with-git
    -- (linked from http://stackoverflow.com/questions/3878624/how-do-i-programmatically-determine-if-there-are-uncommited-changes )
    return read_command(dir, "git diff-index --quiet HEAD || echo dirty"):find("dirty")
  end,
}
