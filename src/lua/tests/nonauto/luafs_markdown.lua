--[[

This example, of a Markdown filesystem, was taken from the "Filesystems"
chapter in the user guide.

]]

--
-- Splits markdown text into sections.
--
-- Returns a table in this form:
--
--   {
--      ["001. Intro"] = "......",
--      ["002. Overview of filesystems"] = "......",
--      ["003. Summary"] = "....."
--   }
--
local function split_sections(text)

  local section_re = [[
    (
      ^ \#+ \s* ([^\n]*)   # Header
      .*?                  # Body
      (?=^\#)              # Stop at the next header.
    )
  ]]

  local sections = {}
  local counter = 1

  for raw, header in (text .. "\n#"):p_gmatch {section_re, "smx"} do
    local numbered_header = ("%03d. %s"):format(counter, header)
    sections[numbered_header] = raw
    counter = counter + 1
  end

  return sections

end


local MarkdownFS = {
  prefix = "markdown",

  -- Convenience: makes pressing ENTER in a panel over MarkDown files
  -- automatically 'cd' to them.
  glob = "*.{md,mkd,mdown}",
}

function MarkdownFS:open_session()

  if fs.stat(self.parent_path, "type") ~= "regular" then
    abort(T"File %s isn't a regular file.":format(self.parent_path.str))
  end

  local text = assert( fs.read(self.parent_path) )

  -- Since MarkDown files are relatively small, we keep all the sections
  -- in memory. For filesystems representing potentially big archives
  -- we'd store in memory just an index to the locations on disk.
  self.sections = split_sections(text)

end

local append = table.insert

-- Reports all the "files" (sections) in our MarkDown file.
function MarkdownFS:readdir(path)
  local names = {}
  for name, _ in pairs(self.sections) do
    append(names, name)
  end
  return names
end

-- Opens a "file".
function MarkdownFS:file(path)
  return self.sections[path]
end

fs.register_filesystem(MarkdownFS)
