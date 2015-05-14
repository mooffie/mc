-- Exposes a panel's files.
--
-- If also injects a "Panelize" button to the dialog. By providing an
-- 'easy_panelize' flag you can make this feature easier to use: this
-- button becomes the default one, and you don't have to mark files
-- in advance.

local append = table.insert

local WorldMeta = {}
WorldMeta.__index = WorldMeta

local function new(...)
  local self = setmetatable({}, WorldMeta)
  self:init(...)
  return self
end

function WorldMeta:init(pnl, opts)
  self.pnl = pnl
  self.universe = utils.table.makeset(fs.dir(self.pnl.dir))
  self.easy_panelize = opts.easy_panelize
end

function WorldMeta:is_utf8()
  return tty.is_utf8()
end

function WorldMeta:get_items()
  if self.easy_panelize then
    -- Expose all files.
    local all = {}
    for fname in self.pnl:files() do
      if fname ~= ".." then
        append(all, fname)
      end
    end
    return all
  else
    -- Expose just the marked files.
    return self.pnl.marked or { self.pnl.current }
  end
end

-- Calculate the number of clashes. That is, the number of files whose
-- target name already exists.
function WorldMeta:calculate_clashes(replacements)

  local universe = self.universe

  local processed = {}
  local clashes_count = 0

  for _, rep in ipairs(replacements) do
    local source, target = rep.source, rep.target
    if universe[target] or processed[target] then
      clashes_count = clashes_count + 1
    end
    processed[target] = true
  end

  return clashes_count

end

local dirname = import_from('utils.path', { 'dirname' })

local function create_folders(replacements)
  local created = {}

  for _, r in ipairs(replacements) do
    if r.target:find "/" then
      local dir = dirname(r.target)
      if not created[dir] then
        fs.mkdir(dir)          -- @todo: change to mkdir_p, once we have it.
        created[dir] = true
      end
    end
  end
end

function WorldMeta:rename(replacements)

  create_folders(replacements)

  local old_files = {}
  local new_files = {}
  for _, r in ipairs(replacements) do
    if r.target ~= "" then  -- skip "" targets.
      append(old_files, r.source)
      append(new_files, r.target)
    end
  end

  mc.mv_i(old_files, new_files)

  self.pnl:reload()
  self.pnl.marked = new_files  -- So that the user can further rename these files.

end

----------------------------- Panelizing support -----------------------------

--
-- The panelizing stuff was added late. It wasn't planned. I'm not happy
-- about exposing the renamer (Controller) to the world (Model), but at least
-- it's local to this function only.
--

function WorldMeta:alter_buttons(buttons, renamer)

  local pnl = self.pnl

  local btn = ui.Button{ T"Paneli&ze",
    on_click = function(self)
      self.dialog:close()
      pnl.marked = nil
      local set = utils.table.makeset(renamer:get_matching_lines())
      pnl:filter_by_fn(function(fname)
        return set[fname]
      end)
      pnl.panelized = true
    end
  }

  if self.easy_panelize then
    buttons[1].type = "normal"
    btn.type = "default"
  end

  table.insert(buttons, 2, btn)  -- Right after the "OK" button.

end

------------------------------------------------------------------------------

return {
  new = new,
}
