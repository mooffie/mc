--[[

Path utilities.

]]

local M = {}

----------------------------- basename & dirname -----------------------------

--[[

A *temporary* implementation for basename/dirname.

It doesn't handle the VFS well (because of "prefix://").

We'll eventually have proper VPath:dir() (returning VPath) and
VPath:basename() (returning string) but in the meantime here's a
simpleminded implementation.

(@todo: would lib/util.c:x_basename() and custom_canonicalize_pathname()
be anyhow useful? Also check out GLib's basename()/dirname() for
semantics.)

]]

function M.basename(s)

  -- Remove trailing "/" on folders.
  if s:sub(-1) == "/" then
    s = s:sub(1,-2)
  end

  return s:match('.*/(.*)') or s

end

local function test_basename()
  local basename = M.basename
  assert(basename("one/two") == "two")
  assert(basename("one/two/") == "two")
  assert(basename("one") == "one")
  assert(basename("/one") == "one")
  assert(basename(".") == ".")     -- Compatible with Ruby & PHP.
  assert(basename("") == "")       -- Compatible with Ruby & PHP. But should be regarded as undefined behavior.
  assert(basename("one//") == "")  -- This shows why you should pass only canonical paths!
  assert(basename("/") == "")      -- Ruby: returns "/". PHP: returns "".
end

function M.dirname(s)

  -- Remove trailing "/" on folders (but not if whole folder is just "/").
  if s:find("./$") then
    s = s:sub(1,-2)
  end

  local dir = s:match('(.*)/')
  if dir then
    return (dir == "") and "/" or dir
  else
    -- No '/' character.
    return "."
  end

end

local function test_dirname()
  local dirname = M.dirname
  assert(dirname("one/two") == "one")
  assert(dirname("one/two/") == "one")
  assert(dirname("one") == ".")
  assert(dirname("/one/two") == "/one")
  assert(dirname("/one") == "/")
  assert(dirname("one/") == ".")
  assert(dirname("/") == "/")
  assert(dirname("//") == "/")
  assert(dirname(".one") == ".")
  assert(dirname(".") == ".")     -- Compatible with Ruby & PHP.
  -- dirname("") is undefined behavior.
end

------------------------------- module_path() --------------------------------

-- Similar to package.searchpath(), which we can't use because Lua 5.1
-- doesn't have it.
local function find_module(name, paths)
  name = name:gsub("%.", "/")
  for path in paths:gmatch("[^;]+") do
    path = path:gsub("?", name)
    if fs.stat(path, "ino") then
      return path
    end
  end
end

---
-- Returns the path to a module.
--
-- Example:
--
--    local help = assert(require "utils.path".module_path("samples.apps.calc", "README.md"))
--    mc.view(help)
--
function M.module_path(name, resource)
  local path = find_module(name, package.path) or find_module(name, package.cpath)
  if path then
    if resource then
      return M.dirname(path) .. "/" .. resource
    else
      return path
    end
  else
    return nil, E"Can't find module '%s'":format(name)
  end
end

------------------------------------------------------------------------------

return M
