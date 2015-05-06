--[[

Shows Arabic/Persian/Hebrew/etc. filenames correctly.

Installation:

    require('samples.fields.bidi')

That's all. It redefines the "name" field to support BiDi.

]]

assert(require('samples.libs.os').try_program('bidiv'), E"It seems that the 'bidiv' program isn't installed.")

local bidi_cache = {}

--
-- Returns a table:
--
-- {
--    filename1 = bidified filename1,
--    filename2 = bidified filename2,
--    ...
-- }
--
local function bidi(dir)

  -- Once we implement io.popen3() we can get rid of this `ls` silliness (and
  -- lift the "local-fs only" restriction.)

  local cmd1 = ("ls -a %q"):format(dir)
  -- The '-w 4096' "protects" against wrapping.
  local cmd2 = ("ls -a %q | bidiv -lj -w 4096"):format(dir)

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

local function get_bidi_cache(dir)
  if not bidi_cache[dir] then
    -- We can't run op-sys commands on non-local filesystem (e.g., inside archives).
    if fs.VPath(dir):is_local() then
      bidi_cache[dir] = bidi(dir)
    else
      bidi_cache[dir] = {}
    end
  end
  return bidi_cache[dir]
end

ui.Panel.bind('<<load>>', function(pnl)
  bidi_cache[pnl.dir] = nil
end)

local function get_bidi_name(dir, fname)
  local db = get_bidi_cache(dir)
  -- The "or" branch is for non-local filesystems.
  return db[fname] or fname
end

ui.Panel.register_field {
  id = "name",
  title = N"&Name",
  sort_indicator = N"sort|n",
  default_width = 12,
  default_align = "left~",
  expands = true,
  render = function(fname, stat, width, info)
    return get_bidi_name(info.dir, fname)
  end,
  sort = "name"
}

--[[

@todo:

- bidiv doesn't preserve all Unicode characters. E.g.:
     פילוסופיה יהודית – ויקיפדיה.mht
     אחת • שתיים.txt
  We'll need to switch to using /usr/bin/fribidi instead.

- MC(?) seems not to like the alif-lam ligature:
     حسين الاكرف.txt

- Investigate fribidi's input/output encoding rules
  to see if we can enable this module by default without
  causing headaches to users.

  Investigate what happens when doing alt-e in the panel
  to set encoding.  @todo  alt-e

]]
