--[[

Displays the GIT branch name at the bottom of the panel. Also indicates
whether the working tree is dirty (uncommitted changes).

Installation:

    require('samples.accessories.git-branch')

]]

local M = {
  style = {
    clean = { color='white, green', mono="reverse" },
    dirty = { color='white, red', mono="reverse" },
  }
}

local git = require('samples.libs.git')

local status_cache = {}

local function get_status(dir)

  local stts = status_cache[dir]

  if stts == nil then
    if git.under_git_control(dir) then
      status_cache[dir] = {
        branch = git.query__branch_name(dir),
        is_dirty = git.query__is_dirty(dir),
      }
    else
      status_cache[dir] = false
    end
    stts = status_cache[dir]
  end

  return stts

end

-- Invalidate the cache on directory read.
ui.Panel.bind('<<load>>', function(pnl)
  status_cache[pnl.dir] = nil
end)


local style = nil

local function draw(pnl)

  -- Compile the styles.
  if not style then
    style = utils.table.map(M.style, tty.style)
  end

  local stts = get_status(pnl.dir)

  if stts then
    local c = pnl:get_canvas()
    c:goto_xy(5, pnl.rows - 1)

    c:set_style(stts.is_dirty and style.dirty or style.clean)
    local s = stts.branch .. (stts.is_dirty and '*' or '')
    c:draw_string(' ' .. s .. ' ')
  end

end

event.bind('ui::skin-change', function()
  style = nil
end)

if git.is_installed() then
  ui.Panel.bind('<<draw>>', draw)
else
  devel.log(E"git-branch.lua: Git isn't installed. I cannot show you the branch status.")
end

return M
