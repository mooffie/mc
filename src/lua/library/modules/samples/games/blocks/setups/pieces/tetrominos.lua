-- http://en.wikipedia.org/wiki/Tetromino

-- Tip: By using a square matrix for a piece we're able to choose its
-- center of rotation.

local p1 = { -- I
  { 0,0,0,0 },
  { 1,1,1,1 },
  { 0,0,0,0 },
  { 0,0,0,0 },
}

local p2 = { -- O
  { 2,2 },
  { 2,2 },
}

local p3 = { -- T
  { 0,0,0 },
  { 3,3,3 },
  { 0,3,0 }
}

local p4 = { -- J
  { 0,0,4 },
  { 0,0,4 },
  { 0,4,4 },
}

local p5 = { -- L
  { 5,0,0 },
  { 5,0,0 },
  { 5,5,0 },
}

local p6 = {  -- S
  { 0,0,0 },
  { 0,6,6 },
  { 6,6,0 }
}

local p7 = { -- Z
  { 0,0,0 },
  { 7,7,0 },
  { 0,7,7 }
}

return {
  pieces = { p1, p2, p3, p4, p5, p6 ,p7 }
}
