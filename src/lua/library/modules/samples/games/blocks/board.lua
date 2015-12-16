--[[

Represents the game's board.

The board is a matrix of numbers. '0' represents empty cells. Any other
number represents a block:

  {
    {0,0,3,0,0},
    {0,3,3,3,0},
    {0,0,0,0,0},
    {0,0,0,0,1},
    {0,2,2,0,1},
    {2,2,0,1,1},
  }

In this board: A "T" starts falling. An "S" and a "J" are on the ground.

]]

local DEFAULT_WD = 10
local DEFAULT_HT = 20

--------------------------------- Data -------------------------------------

-- The board.
local brd = {}      -- It's a matrix (2d array) of cells.
local brd_wd = nil  -- width.
local brd_ht = nil  -- height.

local pieces = nil  -- the catalog of pieces.

local cp = nil  -- the current piece.
local cp_x = 1  -- its (x,y) position.
local cp_y = 1

local score = {
  shapes = 0,  -- how many pieces we've handled.
  lines = 0,   -- how many lines have been squashed.
  points = 0,  -- the actual score, for bragging.
}

-------------------------- Data initialization -----------------------------

-- You may call this to change the setup. E.g., setup('advanced').
local function setup(name)
  local conf = require('samples.games.blocks.setups.' .. name)
  pieces = conf.pieces
  brd_wd = conf.width  or DEFAULT_WD
  brd_ht = conf.height or DEFAULT_HT
end

setup('classic')

local function empty_line()
  local ln = {}
  for x = 1, brd_wd do
    ln[x] = 0
  end
  return ln
end

-- Creates/resets the board. You *must* call this before doing anything with the board.
local function reset_board()

  local function clear_board()
    for y = 1, brd_ht do
      brd[y] = empty_line()
    end
  end

  clear_board()

  score = {
    shapes = 0,
    lines = 0,
    points = 0,
  }

end

---------------- Manipulate the board / the current piece ------------------

-- Rotates a piece 90 degrees clockwise. Returns the rotated version.
local function rotate_piece(p)
  local height = #p
  local width  = #p[1]
  local new = {}

  for x = 1, width do
    new[x] = {}
    for y = 1, height do
      local cell = p[height-y+1][x]
      new[x][y] = cell
    end
  end

  return new
end

-- Tests whether a piece, p, can be placed at position (x,y) on the board.
local function check_room(p, x, y)
  local height = #p
  local width  = #p[1]

  for py = 1, height do
    local prow = p[py]
    for px = 1, width do
      local cell = prow[px]
      if cell ~= 0 then
        local board_y, board_x = y + py - 1, x + px - 1
        if board_y < 1 or board_y > brd_ht then
          return false
        end
        if brd[board_y][board_x] ~= 0 then
          return false
        end
      end
    end
  end

  return true
end

-- Squash all full lines.
-- Returns the number of lines squashed.
local function squash()

  local function line_is_full(n)
    for x = 1, brd_wd do
      if brd[n][x] == 0 then
        return false
      end
    end
    return true
  end

  local function squash_line(n)
    for y = n, 2, -1  do
      brd[y] = brd[y-1]
    end
    brd[1] = empty_line()
  end

  local y = brd_ht
  local count = 0

  while y > 0 do
    if line_is_full(y) then
      squash_line(y)
      count = count + 1
    else
      y = y - 1
    end
  end

  return count
end

-- Welds the current piece to the board.
local function place_piece()
  local height = #cp
  local width  = #cp[1]

  for py = 1, height do
    for px = 1, width do
      local cell = cp[py][px]
      if cell ~= 0 then
        brd[cp_y+py-1][cp_x+px-1] = cell
      end
    end
  end
end

-- Rotates the current piece, if there's room.
local function rotate_current_piece()
  local new = rotate_piece(cp)
  if check_room(new, cp_x, cp_y) then
    cp = new
  end
end

-- Moves the current piece to (x,y), if there's room. Returns 'true' on success.
local function go(x, y)
  if check_room(cp, x, y) then
    cp_x = x
    cp_y = y
    return true
  else
    return false
  end
end

local function go_left()
  return go(cp_x - 1, cp_y)
end

local function go_right()
  return go(cp_x + 1, cp_y)
end

local function go_down()
  return go(cp_x, cp_y + 1)
end

local function go_up()
  return go(cp_x, cp_y - 1)
end

local function new_piece()
  cp = pieces[ math.random(#pieces) ]
  cp_x = math.ceil((brd_wd - #cp[1]) / 2) + 1
  cp_y = 1

  -- @todo: Some pieces have blank line(s) at their top and the following can get
  -- rid of that. But then the user might not be able to rotate them immediately
  -- and he will think it's a bug. The obvious solution is to define those pieces
  -- such that they won't have these blank lines. It's easy. Do other Blocks
  -- games handle this issue the same way?
  --for _ = 1,3 do go_up() end

  return check_room(cp, cp_x, cp_y)
end

-- Move on to the next piece. Returns 'true' if there's place for it (else it means game over).
local function next_piece()
  place_piece()
  local squashed = squash()

  score.lines = score.lines + squashed
  score.points = score.points + 100*squashed*squashed  -- When we squash 2 lines at once, the score doubles.
  score.shapes = score.shapes + 1

  return new_piece()
end

-------------------------------- Drawing -----------------------------------

local colors = nil

local function init_colors()
  colors = {}
  if tty.is_color() then
    colors[0] = tty.style {color="white, black",                hicolor="black,white"}     -- background
    -- tetrominos:
    colors[1] = tty.style {color="brightcyan, black; reverse",  hicolor="white,color038"}  -- I
    colors[2] = tty.style {color="yellow, black; reverse",      hicolor="white,color220"}  -- O
    colors[3] = tty.style {color="white, magenta",              hicolor="white,color133"}  -- T
    colors[4] = tty.style {color="brightblue, black; reverse",  hicolor="white,color032"}  -- J
    colors[5] = tty.style {color="brown, black; reverse",       hicolor="white,color208"}  -- L
    colors[6] = tty.style {color="brightgreen, black; reverse", hicolor="white,color112"}  -- S
    colors[7] = tty.style {color="white, red",                  hicolor="white,color203"}  -- Z
    -- pentominos:
    colors[8] = tty.style {color="white, black; reverse",       hicolor="white,color166"}  -- 5Z
    colors[9] = tty.style {color="white, cyan"}                                            -- 5Zm
  else
    colors[0] = tty.style {mono="base"}
    for i = 1, 9 do
      colors[i] = tty.style {mono="reverse"}
    end
  end
end

local function draw_current_piece(c)
  for y = 1, #cp do
    local row = cp[y]
    for x = 1, #row do
      local cell = row[x]
      if cell ~= 0 then
        c:goto_xy((x+cp_x-2)*2,y+cp_y-2)
        c:set_style(colors[cell])
        --c:draw_string(cell..cell)  -- debug
        c:draw_string('  ')
      end
    end
  end
end

local function draw_board(c)
  if not colors then
    init_colors()
  end

  for y = 1, brd_ht do
    local row = brd[y]
    for x = 1, brd_wd do
      local cell = row[x]
      c:goto_xy((x-1)*2,y-1)
      c:set_style(colors[cell])
      --c:draw_string(cell ~= 0 and (cell..cell) or '..') -- debug
      c:draw_string('  ')
    end
  end
  draw_current_piece(c)
end

----------------------------------------------------------------------------

return {

  setup = setup,
  reset_board = reset_board,
  get_wd = function ()
    return brd_wd
  end,
  get_ht = function ()
    return brd_ht
  end,
  get_score = function ()
    return score
  end,

  new_piece = new_piece,
  next_piece = next_piece,
  rotate_current_piece = rotate_current_piece,

  go_left = go_left,
  go_right = go_right,
  go_up = go_up,
  go_down = go_down,

  draw_board = draw_board,

}
