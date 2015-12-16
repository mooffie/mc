---
-- @module mc

local mc = require("c.mc")

--[[-

File operations.

The following functions let you copy/move/delete files (and _directories_
-- we don't distinguish between the two here). They deal with whole files
(in contrast to the low level API of the @{fs} module.)

Specifying files: Each of the arguments __src__, __dst__, and __files__
may be either a single filepath or a list of such. Example:

    cp('one.txt', 'two.txt')
    cp({'one.txt', 'two.txt'}, 'dir')

[info]

You can also do:

    cp({'one.txt', 'two.txt'}, {'one.md', 'two.md'})

which is like doing:

    cp('one.txt', 'one.md')
    cp('two.txt', 'two.md')

But the former is better because it uses one _context_. If the user is
asked about overwriting a file and chooses "All", his choice will be
remembered for the second file as well. On the other hand, when using
two separate cp() calls, two unrelated contexts are used.

[/info]

The optional __opts__ argument is a table of options. For example:

- deref - Whether to dereference symbolic links.
- BUFSIZ - The buffer size for reading/writing. The default is 1MB.

This table is in fact merged into the @{git:fileops/contexts|context} object.

@section
]]

local function create_fileop_context(id)
  return require('fileops.contexts.' .. id).create_context()
end

local function merge(base, extra)
  assert(type(extra) == "table")
  for k, v in pairs(extra) do
    base[k] = v
  end
end

local function exec_fileop(op_name, ctx_id, opts, ...)
  local ctx = create_fileop_context(ctx_id)
  if opts then
    merge(ctx, opts)
  end
  return require('fileops.' .. op_name)[op_name](ctx, ...)
end

--- Copies files.
--
-- A simple example:
--
--    mc.cp(tglob('/etc/*.conf'), '.')
--
-- Another example:
--
--    -- Download all *.pdf files from a remote server to the current
--    -- directory, but only files that are newer than what we already
--    -- have.
--
--    mc.cp(
--      fs.tglob('sh://john@example.com/vhosts/john/public_html/tmp/*.pdf'),
--      '.',
--      {
--        decide_on_overwrite = function (src, dst)
--          return "update"
--        end,
--      }
--    )
--
--    -- UPDATE: MC seems to have a bug when handling dates over
--    --         'sh://': the date will be "translated" over the
--    --         timezone. So the "update" trick above won't work
--    --         as expected :-(
--
-- @args (src, dst[, opts])
function mc.cp(src, dst, opts)
  local ctx_id = tty.is_ui_ready() and 'passive' or 'batch'
  return exec_fileop('copy', ctx_id, opts, src, dst)
end

--- Copies files, interactively.
--
-- If the destination already exists, the user will be asked if he wants
-- to overwrite it, etc. So in the case of other scenarios demanding a
-- decision.
--
-- Tip-short: the **i** in the function name comes from the shell command `cp -i`.
--
-- Note: If the UI isn't @{tty.is_ui_ready|ready} (and hence questions can't
-- be posed to the user), this function behaves like @{cp}.
--
-- @args (src, dst[, opts])
function mc.cp_i(src, dst, opts)
  local ctx_id = tty.is_ui_ready() and 'interactive' or 'batch'
  return exec_fileop('copy', ctx_id, opts, src, dst)
end

--- Moves (or renames) files.
-- @args (src, dst[, opts])
function mc.mv(src, dst, opts)
  local ctx_id = tty.is_ui_ready() and 'passive' or 'batch'
  return exec_fileop('move', ctx_id, opts, src, dst)
end

--- Moves (or renames) files, interactively.
--
-- For the meaning of "interactively", see in @{cp_i}.
--
-- @args (src, dst[, opts])
function mc.mv_i(src, dst, opts)
  local ctx_id = tty.is_ui_ready() and 'interactive' or 'batch'
  return exec_fileop('move', ctx_id, opts, src, dst)
end

--- Deletes files.
-- @args (files[, opts])
function mc.rm(files, opts)
  local ctx_id = tty.is_ui_ready() and 'passive' or 'batch'
  return exec_fileop('delete', ctx_id, opts, files)
end

--- Deletes files, interactively.
-- @args (files[, opts])
function mc.rm_i(files, opts)
  local ctx_id = tty.is_ui_ready() and 'interactive' or 'batch'
  return exec_fileop('delete', ctx_id, opts, files)
end

--- @section end

return mc
