--[[

Alternative file-locking implementation.

It is used by the 'samples.editbox.locking' module. See explanation there.

Implementation notes:

- We don't care about race conditions: we're dealing with the interaction
  of a single user.

- The locks are stored in a dedicated directory (in contrast to each lock being
  stored in the directory in which the locked file resides, as currently in MC).

  This is intentional: it lets application like "Recently visited files" show
  all the files the user currently edits on the computer, even if he's using
  several MC processes.

]]

local append = table.insert

local M = {

  --
  -- Where to place the lock files.
  --
  -- (This typically ends up in ~/.cache/mc/mcedit.locks.)
  --
  dir = conf.dirs.user_cache .. '/mcedit.locks',

  --
  -- Locks older than this age will be considered invalid,
  -- even if there exists a process with the same PID that
  -- created them.
  --
  stale_lock_age = 10*24*60*60,  -- 10 days (in seconds).

}

------------------------------- Path handling --------------------------------

local ext = '.lck'

--
-- We hash the resource name[1] to figure out its lock file's path.
--
-- We use SHA-1 by default. If it's not available, we fallback to some
-- stupid gsub() "hashing" (where collisions are possible).
--
-- BTW, a similar scheme is used by:
--
--   http://specifications.freedesktop.org/thumbnail-spec/thumbnail-spec-latest.html
--
-- [1] The term "resource name", in this file, means: the absolute path
--     of the file we're locking
--
local hash = utils.text.transport.hash
               and function(s) return utils.text.transport.hash('sha1', s) end
               or  function(s) return s:gsub('[^a-zA-Z]','-') end

--
-- Returns the lock file's path that would store a resource's lock.
--
local function lock_path(resource_name)
  return M.dir .. '/' .. hash(resource_name) .. ext
end

--
-- Returns a list of all the lock files (whether valid or invalid).
--
local function lock_files()
  return utils.table.new(fs.tglob(M.dir .. '/*' .. ext))
end

------------------------------------ lock ------------------------------------

function M.lock(resource_name)
  local f = assert(io.open(lock_path(resource_name), "w"))
  f:write(resource_name, "\n")
  f:write(os.getpid(), "\n")
  f:close()
end

----------------------------------- unlock -----------------------------------

function M.unlock(resource_name)
  fs.unlink(lock_path(resource_name))
end

-------------------------------- information ---------------------------------

local function read_lock_file(path)
  local f = assert(fs.open(path, "r"))
  if f then
    return {
      resource_name = f:read('*l'),
      pid = tonumber(f:read('*l')),
      age = os.time() - f:stat('mtime'),
    }
  end
end

function M.get_lock_info(resource_name)
  return read_lock_file(lock_path(resource_name))
end

----------------------------------- query ------------------------------------

local function process_exists(pid)
  return os.kill(pid, 0) == true
end

local function is_valid(rec)
  return rec and process_exists(rec.pid) and (rec.age < M.stale_lock_age)
end

local function validate_lock(resource_name)
  return is_valid(M.get_lock_info(resource_name))
end

function M.is_locked(resource_name)
  return fs.nonvfs_access(lock_path(resource_name), "") and validate_lock(resource_name)
end

------------------------------------ misc ------------------------------------

--
-- Returns all valid locks.
--
function M.get_locks()
  return lock_files():map(read_lock_file):filter(is_valid)
end

--------------------------- Setup and maintenance ----------------------------

--
-- Deletes all invalid lock files.
--
-- They are, for example, the result of possible MC crashes.
--
local function cleanup()
  for f in lock_files():iterate() do
    if not is_valid(read_lock_file(f)) then
      fs.unlink(f)
    end
  end
end

local function setup()
  -- Create the lock directory, if not exists.
  if not fs.stat(M.dir) then
    assert(fs.nonvfs_mkdir_p(M.dir))
  end
  -- Run the cleanup procedure sometimes (25% probability).
  if math.random() < 0.25 then
    cleanup()
  end
end

------------------------------------------------------------------------------

setup()

return M
