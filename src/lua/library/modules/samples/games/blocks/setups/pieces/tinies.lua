-- Tiny pieces.

local p1 = { -- .
  { 1 },
}

local p2 = { -- ,
  { 2, 2 },
}

local p3 = { -- V
  { 0,3 },
  { 3,3 },
}

local p4 = { -- I
  { 0,4,0 },
  { 0,4,0 },
  { 0,4,0 },
}

return {
  pieces = { p1, p2, p3, p4 }
}
