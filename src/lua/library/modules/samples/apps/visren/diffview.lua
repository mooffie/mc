--
-- A custom widget that displays a "diff" side-by-side.
--
-- It gets its data from a "provider" object that has to implement two
-- methods: get_diffs() and matching_lines_count().
--

local style = nil

local function init_style()
  style = {
    norm = tty.style('dialog._default_'),
    match_same = tty.style('diffviewer.added'),
    match_differ = tty.style('diffviewer.removed'),
  }
end

local DiffviewMeta = ui.Custom.subclass("Diffview")

DiffviewMeta.__allowed_properties = {
  first_col = true, -- when scrolling, the leftmost character visible.
  top_line = true,  -- when scrolling, the topmost line visible.
  _side_by_side = true,
  _provider = true,
}

function DiffviewMeta:init()
  init_style()
  self.first_col = 1
  self.top_line = 1
end

function DiffviewMeta:set_side_by_side(b)
  self._side_by_side = b
  self.first_col = 1  -- as it might be out of view now.
  self:redraw()
end

--
-- Calculates the coordinates of the two columns.
--
function DiffviewMeta:calculate_columns()

  if self._side_by_side then

    -- The coordinates do *not* include the frame.
    -- The magic numbers "1", "- 2", "+ 2", "- 4", are the frame borders.

    local left_column = { x = 1, y = 1, cols = math.floor(self.cols / 2) - 2, rows = self.rows - 2 }
    local right_column = { x = nil, y = 1, cols = nil, rows = self.rows - 2 }
    right_column.x = left_column.x + left_column.cols + 2
    right_column.cols = self.cols - left_column.cols - 4

    return left_column, right_column

  else

    local up_column = { x = 1, y = 1, rows = math.floor(self.rows / 2) - 2, cols = self.cols - 2 }
    local down_column = { x = 1, y = nil, cols = self.cols - 2 }
    down_column.y = up_column.y + up_column.rows + 2
    down_column.rows = self.rows - up_column.rows - 4

    return up_column, down_column

  end

end

--
-- Draw!
--
function DiffviewMeta:on_draw()
  local c = self:get_canvas()
  c:erase()

  local source_column, target_column = self:calculate_columns()

  local function draw_frame(col, title)
    c:draw_box(col.x-1, col.y-1, col.cols+2, col.rows+2)
    c:goto_xy(col.x+1, col.y-1)
    c:draw_string((" %s "):format(title))
  end

  local left_arrow = tty.skin_get('widget-panel.filename-scroll-left-char', '<')
  local right_arrow = tty.skin_get('widget-panel.filename-scroll-right-char', '>')

  -- Draw a single line.
  local function draw_item(segments, col, y, branch_name, other_branch_name)
    local x = col.x - (self.first_col - 1)
    for _, segment in ipairs(segments) do
      local is_match = (type(segment) == "table")

      local branch = is_match and segment[branch_name] or segment
      local other_branch = is_match and segment[other_branch_name] or segment
      local same = (branch == other_branch)

      c:set_style(is_match
                    and (same and style.match_same or style.match_differ)
                    or  style.norm)
      c:draw_clipped_string(x, y + col.y, branch, col.x, col.x + col.cols)
      x = x + tty.text_width(branch)
      if self.first_col ~= 1 then
        c:goto_xy(col.x, y + col.y)
        c:draw_string(left_arrow)
      end
      if x > col.x + col.cols then
        c:goto_xy(col.x + col.cols - 1, y + col.y)
        c:draw_string(right_arrow)
      end
    end
  end

  local data_lines = math.max(source_column.rows, target_column.rows)

  -- Draw all the visible lines:

  local diffs = self._provider:get_diffs(self.top_line, data_lines)

  for y = 1, #diffs do

    local segments = diffs[y]

    draw_item(segments, source_column, y-1, 'source', 'target')
    draw_item(segments, target_column, y-1, 'target', 'source')

  end

  -- And the frames.
  --
  -- We do this after drawing the data itself because, when not
  -- side-by-side, one of the columns is often 1-line taller than the other
  -- so it paints over its frame.
  draw_frame(source_column, T"Before")
  draw_frame(target_column, T"After")

end

function DiffviewMeta:char_right()
  self.first_col = self.first_col + 1
end

function DiffviewMeta:char_left()
  self.first_col = math.max(1, self.first_col - 1)
end

function DiffviewMeta:line_down()
  self.top_line = self.top_line + 1
  self:ensure_visibility()
end

-- How many data lines are shown.
function DiffviewMeta:contents_height()
  local source_column, target_column = self:calculate_columns()
  return math.min(source_column.rows, target_column.rows) -- We need to go by the shorter column (only relevant when not side_by_side).
end

function DiffviewMeta:line_up()
  self.top_line = math.max(1, self.top_line - 1)
end

function DiffviewMeta:page_down()
  self.top_line = self.top_line + (self:contents_height() - 1)
  self:ensure_visibility()
end

function DiffviewMeta:page_up()
  self.top_line = math.max(1, self.top_line - (self:contents_height() - 1))
end

-- Fix top_line to be inside of bounds.
function DiffviewMeta:ensure_visibility()
  self.top_line = math.max(math.min(self.top_line, self._provider:matching_lines_count() - self:contents_height() + 1), 1)
end

function DiffviewMeta:set_provider(provider)
  self._provider = provider
end

function DiffviewMeta:on_mouse_down(x, y, buttons)
  if buttons.up then
    self:line_up()
    self:redraw()
  elseif buttons.down then
    self:line_down()
    self:redraw()
  end
end
