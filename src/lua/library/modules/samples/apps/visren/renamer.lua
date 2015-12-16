--
-- The Renamer does the renaming.
--
-- Not quite: the Renamer doesn't know how to rename files or replace lines in
-- an editor. It delegates the actual work to a World object.
--
-- In MVC speak, you can think of the Renamer as a controller and
-- a World as a model.
--

local append = table.insert
local create_search_context = require('samples.apps.visren.search').create_search_context

local Renamer = {}
Renamer.__index = Renamer

local function new(...)
  local self = setmetatable({}, Renamer)
  self:init(...)
  return self
end

function Renamer:init(world)
  self.world = world
  self.lines = world:get_items()
  self.clashes = 0
  self:set_env('pcre', true, true, true)  -- creates an initial, dummy searcher. (not really needed.)
end


function Renamer:get_diffs(from, count)
  local diffs = {}
  local searcher = self.searcher

  if searcher:has_pattern() then

    for i = from, math.min(from + count - 1, #self.matching_lines) do
      searcher:set_buffer(self.matching_lines[i])
      append(
        diffs,
        searcher:replace__as_segments()
      )
    end

  end

  return diffs
end

-- Returns: (matching lines count, total lines count, clashes count)
function Renamer:get_status()
  return #self.matching_lines, #self.lines, self.clashes
end

function Renamer:has_clashes()
  return self.clashes ~= 0
end

function Renamer:matching_lines_count()
  return #self.matching_lines
end

function Renamer:generate_replacements()
  local replacements = {}
  local searcher = self.searcher

  for _, source in ipairs(self.matching_lines) do
    searcher:set_buffer(source)
    local target = searcher:replace()
    if source ~= target then
      -- We use an array as we want to keep the order.
      append(replacements, {
        source = source,
        target = target
      })
    end
  end

  return replacements
end

function Renamer:calculate_clashes()
  -- Worlds that don't have a notion of clashes don't implement
  -- calculate_clashes(). This way precious time is saved because
  -- generate_replacements() can be costly, especially for a global
  -- empty pattern.
  if self.world.calculate_clashes then
    local replacements = self:generate_replacements()
    self.clashes = self.world:calculate_clashes(replacements)
  end
end

-- Find out the matching lines.
function Renamer:run_match()
  local matching = {}
  local searcher = self.searcher

  for _, ln in ipairs(self.lines) do
    searcher:set_buffer(ln)
    if searcher:does_match() then
      append(matching, ln)
    end
  end

  self.matching_lines = matching
  self:calculate_clashes()
end

function Renamer:get_matching_lines()
  return self.matching_lines
end

-- Rename!
function Renamer:do_rename()
  local replacements = self:generate_replacements()
  self.world:rename(replacements)
end

--------------------------- search parameters ------------------------------

function Renamer:set_env(lib, is_utf8, is_case_sensitive, is_global)
  self.searcher = create_search_context(lib, is_utf8, is_case_sensitive, is_global)
  self.matching_lines = {}
end

function Renamer:set_pattern(pat)
  local ok, errmsg = self.searcher:set_pattern(pat)

  if ok then
    self:run_match()
    return true
  else
    return false, errmsg
  end

end

function Renamer:set_template(raw_template)
  self.searcher:set_template(raw_template)
end

----------------------------------------------------------------------------

return {
  new = new,
}
