
local function merge(base, ext, ...)
  if ext then
    for _, v in ipairs(ext) do
      base[#base + 1] = v
    end
    return merge(base, ...)
  else
    return base
  end
end

return {
  pieces = merge(
    {},
    require('samples.games.blocks.setups.pieces.tetrominos').pieces, -- 7 pieces.
    require('samples.games.blocks.setups.pieces.tetrominos').pieces, -- 7 pieces.
    require('samples.games.blocks.setups.pieces.pentominos').pieces, -- 18 pieces.
    require('samples.games.blocks.setups.pieces.tinies').pieces,     -- 4 pieces.
    require('samples.games.blocks.setups.pieces.tinies').pieces      -- 4 pieces.
  ),
  width = 14, -- This board is harder, so we make it wider than the default.
}
